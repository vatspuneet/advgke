#!/bin/bash
set -e

# --- Configuration ---
PROJECT_ID=$(gcloud config get-value project)
REGION="asia-east1"
VPC_NAME="vpc-black"
SUBNET_NAME="asia-east-1"
SUBNET_RANGE="10.142.0.0/20"
CLUSTER_NAME="c1-black"
DOMAIN_NAME="testapp.com"

# Colors
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}=== Starting GKE Internal Site Setup (testapp.com) ===${NC}"

# ---------------------------------------------------------
# 1. Network Infrastructure
# ---------------------------------------------------------
echo -e "${GREEN}[1/9] Creating VPC and Subnet...${NC}"
gcloud compute networks create $VPC_NAME \
    --subnet-mode=custom \
    --project=$PROJECT_ID || echo "VPC exists"

gcloud compute networks subnets create $SUBNET_NAME \
    --network=$VPC_NAME \
    --region=$REGION \
    --range=$SUBNET_RANGE \
    --project=$PROJECT_ID || echo "Subnet exists"

# Firewall for Ingress Health Checks
gcloud compute firewall-rules create allow-glbc-health-checks-internal \
    --network=$VPC_NAME \
    --allow=tcp:80,tcp:443 \
    --source-ranges=130.211.0.0/22,35.191.0.0/16 \
    --project=$PROJECT_ID || echo "Firewall rule exists"

# ---------------------------------------------------------
# 2. GKE Autopilot Cluster
# ---------------------------------------------------------
echo -e "${GREEN}[2/9] Creating Autopilot Cluster '$CLUSTER_NAME'...${NC}"
gcloud container clusters create-auto $CLUSTER_NAME \
    --region=$REGION \
    --network=$VPC_NAME \
    --subnetwork=$SUBNET_NAME \
    --project=$PROJECT_ID

echo -e "${GREEN}[3/9] Getting Credentials...${NC}"
gcloud container clusters get-credentials $CLUSTER_NAME --region=$REGION

# ---------------------------------------------------------
# 3. Generate Self-Signed Certificate
# ---------------------------------------------------------
echo -e "${GREEN}[4/9] Generating Self-Signed Certificate for $DOMAIN_NAME...${NC}"
# Generate a private key and certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout tls.key -out tls.crt \
    -subj "/CN=$DOMAIN_NAME/O=Test Internal App"

# Create Kubernetes Secret
kubectl create secret tls website-tls-secret \
    --key tls.key \
    --cert tls.crt \
    --dry-run=client -o yaml | kubectl apply -f -

# Clean up local files
rm tls.key tls.crt

# ---------------------------------------------------------
# 4. Reserve Static IP
# ---------------------------------------------------------
echo -e "${GREEN}[5/9] Reserving Static IP for Ingress...${NC}"
gcloud compute addresses create web-ip-static --global --project=$PROJECT_ID || echo "IP exists"
STATIC_IP=$(gcloud compute addresses describe web-ip-static --global --format="value(address)")
echo "Reserved Static IP: $STATIC_IP"

# ---------------------------------------------------------
# 5. Deploy Kubernetes Resources
# ---------------------------------------------------------
echo -e "${GREEN}[6/9] Applying Kubernetes Manifests...${NC}"

cat <<EOF | kubectl apply -f -
# --- 1. Frontend Deployment (Website) ---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: website
  labels:
    app: website
    role: front-end
spec:
  replicas: 2
  selector:
    matchLabels:
      app: website
      role: front-end
  template:
    metadata:
      labels:
        app: website
        role: front-end
    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
        - containerPort: 80

---
# --- 2. Frontend Service (NodePort) ---
apiVersion: v1
kind: Service
metadata:
  name: website-service
spec:
  selector:
    app: website
    role: front-end
  type: NodePort
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80

---
# --- 3. Ingress (HTTPS with Self-Signed Cert) ---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: website-ingress
  annotations:
    kubernetes.io/ingress.global-static-ip-name: web-ip-static
    kubernetes.io/ingress.class: "gce"
spec:
  tls:
  - secretName: website-tls-secret
    hosts:
    - $DOMAIN_NAME
  rules:
  - host: $DOMAIN_NAME
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: website-service
            port:
              number: 80

---
# --- 4. Database Deployment ---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: db-app
  labels:
    app: db-app
    role: database
spec:
  replicas: 2
  selector:
    matchLabels:
      app: db-app
      role: database
  template:
    metadata:
      labels:
        app: db-app
        role: database
    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
        - containerPort: 80

---
# --- 5. Database Service (ClusterIP) ---
apiVersion: v1
kind: Service
metadata:
  name: db-service
spec:
  selector:
    app: db-app
    role: database
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
  type: ClusterIP

---
# --- 6. Network Policy ---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: db-access-policy
spec:
  podSelector:
    matchLabels:
      role: database
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          role: front-end
    ports:
    - protocol: TCP
      port: 80

---
# --- 7. Test Pod (Unauthorized) ---
apiVersion: v1
kind: Pod
metadata:
  name: nginx-red
  labels:
    app: nginx-red
    role: unauthorized
spec:
  containers:
  - name: nginx
    image: nginx
EOF

# ---------------------------------------------------------
# 6. Waiting for Resources
# ---------------------------------------------------------
echo -e "${GREEN}[7/9] Waiting for Pods to be ready...${NC}"
kubectl wait --for=condition=ready pod --all --timeout=120s

# ---------------------------------------------------------
# 7. Network Policy Tests (Internal)
# ---------------------------------------------------------
echo -e "${GREEN}[8/9] Running Internal Network Policy Tests...${NC}"

DB_SVC_IP=$(kubectl get svc db-service -o jsonpath='{.spec.clusterIP}')
WEBSITE_POD=$(kubectl get pod -l role=front-end -o jsonpath='{.items[0].metadata.name}')

echo "--- Test 1: Website Pod -> DB Service (Should PASS) ---"
kubectl exec $WEBSITE_POD -- curl -s --connect-timeout 2 $DB_SVC_IP > /dev/null
if [ $? -eq 0 ]; then echo "✅ PASS"; else echo "❌ FAIL"; fi

echo "--- Test 2: Nginx-Red Pod -> DB Service (Should FAIL) ---"
kubectl exec nginx-red -- curl -s --connect-timeout 2 $DB_SVC_IP > /dev/null
if [ $? -ne 0 ]; then echo "✅ PASS (Blocked)"; else echo "❌ FAIL (Did not block)"; fi

# ---------------------------------------------------------
# 8. HTTPS Test (External)
# ---------------------------------------------------------
echo -e "${GREEN}[9/9] Testing External HTTPS Access (This may take 5-10 mins for LB to provision)...${NC}"
echo "Waiting for Load Balancer IP to be reachable..."

# Simple wait loop for the LB to start responding
RETRIES=0
while [ $RETRIES -lt 20 ]; do
    # We use -k (insecure) because it is a self-signed cert
    # We use --resolve to force testapp.com to map to our Static IP
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -k --resolve $DOMAIN_NAME:443:$STATIC_IP https://$DOMAIN_NAME/)
    
    if [ "$HTTP_CODE" == "200" ]; then
        echo "✅ SUCCESS: Accessed https://$DOMAIN_NAME (Code: 200)"
        echo "Verification command used:"
        echo "curl -v -k --resolve $DOMAIN_NAME:443:$STATIC_IP https://$DOMAIN_NAME/"
        break
    else
        echo "Waiting for LB... (Current Code: $HTTP_CODE)"
        sleep 30
        RETRIES=$((RETRIES+1))
    fi
done

echo "Setup Complete!"
