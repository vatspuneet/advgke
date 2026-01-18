#!/bin/bash
set -e

PROJECT_ID=$(gcloud config get-value project)
REGION="us-central1"
CLUSTER_NAME="pki-ingress-demo"
DOMAIN="demo.example.com"

echo "=== PKI Security Demo with Ingress ==="

# 1. Create Cluster
echo "[1/6] Creating Cluster..."
gcloud container clusters create-auto $CLUSTER_NAME \
    --region=$REGION \
    --project=$PROJECT_ID

gcloud container clusters get-credentials $CLUSTER_NAME --region=$REGION

# 2. Create PKI Certificates
echo "[2/6] Creating PKI Certificates..."
mkdir -p pki-certs && cd pki-certs

# Frontend cert (Client to LB)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout frontend.key -out frontend.crt -subj "/CN=$DOMAIN"

# Backend cert (LB to Pod)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout backend.key -out backend.crt -subj "/CN=secure-backend"

cd ..

# 3. Create Secrets
echo "[3/6] Creating Secrets..."
kubectl create secret tls frontend-tls --cert=pki-certs/frontend.crt --key=pki-certs/frontend.key
kubectl create secret tls backend-tls --cert=pki-certs/backend.crt --key=pki-certs/backend.key

# 4. Reserve Static IP
echo "[4/6] Reserving Static IP..."
gcloud compute addresses create pki-ingress-ip --global --project=$PROJECT_ID || true
STATIC_IP=$(gcloud compute addresses describe pki-ingress-ip --global --format="value(address)")
echo "Static IP: $STATIC_IP"

# 5. Deploy Backend with TLS and Ingress
echo "[5/6] Deploying Applications and Ingress..."
cat <<EOF | kubectl apply -f -
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: backend-nginx-conf
data:
  nginx.conf: |
    events {}
    http {
      server {
        listen 8443 ssl;
        ssl_certificate /etc/nginx/certs/tls.crt;
        ssl_certificate_key /etc/nginx/certs/tls.key;
        location / { return 200 "PKI Demo: TLS End-to-End OK\n"; }
      }
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-backend
spec:
  replicas: 2
  selector: {matchLabels: {app: secure-backend}}
  template:
    metadata: {labels: {app: secure-backend}}
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 8443
        volumeMounts:
        - name: certs
          mountPath: /etc/nginx/certs
          readOnly: true
        - name: conf
          mountPath: /etc/nginx/nginx.conf
          subPath: nginx.conf
      volumes:
      - name: certs
        secret: {secretName: backend-tls}
      - name: conf
        configMap: {name: backend-nginx-conf}
---
apiVersion: v1
kind: Service
metadata:
  name: secure-backend
  annotations:
    cloud.google.com/app-protocols: '{"https":"HTTPS"}'
spec:
  selector: {app: secure-backend}
  ports:
  - name: https
    port: 8443
    targetPort: 8443
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: pki-ingress
  annotations:
    kubernetes.io/ingress.global-static-ip-name: pki-ingress-ip
    kubernetes.io/ingress.class: gce
spec:
  tls:
  - secretName: frontend-tls
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: secure-backend
            port:
              number: 8443
EOF

# 6. Test
echo "[6/6] Waiting for Ingress and Testing..."
kubectl wait --for=condition=ready pod -l app=secure-backend --timeout=180s

echo "Waiting for Ingress IP..."
for i in {1..30}; do
    ING_IP=$(kubectl get ingress pki-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    if [ -n "$ING_IP" ]; then
        break
    fi
    echo -n "."
    sleep 10
done
echo ""

echo "=== Demo Complete ==="
echo "Ingress IP: $STATIC_IP"
echo ""
echo "Architecture:"
echo "  Client --[TLS: frontend cert]--> Ingress/LB --[TLS: backend cert]--> Pod"
echo ""
echo "Test with:"
echo "  curl -k https://$STATIC_IP"
echo ""
echo "Internal test (LB to Pod TLS):"
kubectl run test-curl --rm -it --restart=Never --image=curlimages/curl -- curl -sk https://secure-backend:8443 || true
