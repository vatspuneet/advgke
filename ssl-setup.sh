#!/bin/bash
set -e

# --- Configuration ---
PROJECT_ID=$(gcloud config get-value project)
REGION="asia-east1"
VPC_NAME="vpc-black"
SUBNET_NAME="asia-east-1"
SUBNET_RANGE="10.142.0.0/20"
CLUSTER_NAME="c1-black"
CERT_NAME="website-gcp-cert"
DOMAIN="testapp.com"

echo "=== Starting Setup for $PROJECT_ID ==="

# 1. Network & Firewall
echo "[1/7] Creating Network..."
gcloud compute networks create $VPC_NAME --subnet-mode=custom --project=$PROJECT_ID || true
gcloud compute networks subnets create $SUBNET_NAME --network=$VPC_NAME --region=$REGION --range=$SUBNET_RANGE --project=$PROJECT_ID || true

# Required for Load Balancer Health Checks
gcloud compute firewall-rules create allow-lb-health-checks \
    --network=$VPC_NAME --allow=tcp:80,tcp:443 \
    --source-ranges=130.211.0.0/22,35.191.0.0/16 --project=$PROJECT_ID || true

# 2. Cluster
echo "[2/7] Creating Autopilot Cluster (may take 5-8 mins)..."
gcloud container clusters create-auto $CLUSTER_NAME \
    --region=$REGION --network=$VPC_NAME --subnetwork=$SUBNET_NAME --project=$PROJECT_ID

gcloud container clusters get-credentials $CLUSTER_NAME --region=$REGION

# 3. Certificate & Static IP
echo "[3/7] Generating and Uploading SSL Certificate..."
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=$DOMAIN"
# Upload to Google Cloud
gcloud compute ssl-certificates create $CERT_NAME --certificate=tls.crt --private-key=tls.key --global --project=$PROJECT_ID || echo "Cert exists"
rm tls.key tls.crt

echo "[4/7] Reserving Static IP..."
gcloud compute addresses create web-ip-static --global --project=$PROJECT_ID || true
STATIC_IP=$(gcloud compute addresses describe web-ip-static --global --format="value(address)")
echo "Static IP: $STATIC_IP"

# 4. Deploy Manifests
echo "[5/7] Deploying Apps, Ingress, and Policies..."
cat <<EOF | kubectl apply -f -
# --- Frontend (Website) ---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: website
  labels: {app: website, role: front-end}
spec:
  replicas: 2
  selector: {matchLabels: {app: website}}
  template:
    metadata: {labels: {app: website, role: front-end}}
    spec:
      containers: [{name: nginx, image: nginx, ports: [{containerPort: 80}]}]
---
apiVersion: v1
kind: Service
metadata: {name: website-service}
spec:
  type: NodePort
  selector: {app: website}
  ports: [{port: 80, targetPort: 80}]
---
# --- Ingress (Uses GCP Cert) ---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: website-ingress
  annotations:
    kubernetes.io/ingress.global-static-ip-name: web-ip-static
    kubernetes.io/ingress.class: "gce"
    ingress.gce.kubernetes.io/pre-shared-cert: "$CERT_NAME"
spec:
  rules:
  - host: $DOMAIN
    http:
      paths:
      - path: /
        pathType: Prefix
        backend: {service: {name: website-service, port: {number: 80}}}
---
# --- DB App ---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: db-app
  labels: {app: db-app, role: database}
spec:
  replicas: 2
  selector: {matchLabels: {app: db-app}}
  template:
    metadata: {labels: {app: db-app, role: database}}
    spec:
      containers: [{name: nginx, image: nginx, ports: [{containerPort: 80}]}]
---
apiVersion: v1
kind: Service
metadata: {name: db-service}
spec:
  type: ClusterIP
  selector: {app: db-app}
  ports: [{port: 80, targetPort: 80}]
---
# --- Network Policy ---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: {name: db-access-policy}
spec:
  podSelector: {matchLabels: {role: database}}
  policyTypes: [Ingress]
  ingress:
  - from: [{podSelector: {matchLabels: {role: front-end}}}]
    ports: [{protocol: TCP, port: 80}]
---
# --- Test Pod (Unauthorized) ---
apiVersion: v1
kind: Pod
metadata: {name: nginx-red, labels: {role: unauthorized}}
spec:
  containers: [{name: nginx, image: nginx}]
EOF

# 5. Internal Tests
echo "[6/7] Waiting for Pods and running Internal Tests..."
kubectl wait --for=condition=ready pod --all --timeout=120s
DB_IP=$(kubectl get svc db-service -o jsonpath='{.spec.clusterIP}')
WEB_POD=$(kubectl get pod -l role=front-end -o name | head -1)

echo "--- Test 1: Website -> DB (Should PASS) ---"
kubectl exec $WEB_POD -- curl -s -m 2 $DB_IP > /dev/null && echo "✅ PASS" || echo "❌ FAIL"

echo "--- Test 2: Nginx-Red -> DB (Should FAIL) ---"
if ! kubectl exec nginx-red -- curl -s -m 2 $DB_IP > /dev/null; then echo "✅ PASS (Blocked)"; else echo "❌ FAIL (Not Blocked)"; fi

# 6. External HTTPS Test
echo "[7/7] Testing HTTPS (Waiting for Load Balancer)..."
echo "Target: https://$DOMAIN ($STATIC_IP)"
for i in {1..20}; do
    CODE=$(curl -s -o /dev/null -w "%{http_code}" -k --resolve $DOMAIN:443:$STATIC_IP https://$DOMAIN/)
    if [ "$CODE" == "200" ]; then
        echo "✅ SUCCESS: HTTPS Reachable (200 OK)"
        break
    fi
    echo -n "."
    sleep 30
done
echo "Done!"
