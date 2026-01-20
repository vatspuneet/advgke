#!/bin/bash
set -e

PROJECT_ID=$(gcloud config get-value project)
REGION="us-central1"
CLUSTER_NAME="netpol-demo"

echo "=== Network Policies Demo with Autopilot ==="

# 1. Create Autopilot Cluster
echo "[1/4] Creating Autopilot Cluster..."
gcloud container clusters create-auto $CLUSTER_NAME \
    --region=$REGION \
    --project=$PROJECT_ID

gcloud container clusters get-credentials $CLUSTER_NAME --region=$REGION

# 2. Create namespaces
echo "[2/4] Creating namespaces..."
kubectl create namespace frontend
kubectl create namespace backend
kubectl create namespace restricted

# 3. Deploy test pods
echo "[3/4] Deploying test pods..."
cat <<EOF | kubectl apply -f -
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: frontend
spec:
  replicas: 1
  selector: {matchLabels: {app: web, role: frontend}}
  template:
    metadata: {labels: {app: web, role: frontend}}
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports: [{containerPort: 80}]
---
apiVersion: v1
kind: Service
metadata:
  name: web
  namespace: frontend
spec:
  selector: {app: web}
  ports: [{port: 80}]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  namespace: backend
spec:
  replicas: 1
  selector: {matchLabels: {app: api, role: backend}}
  template:
    metadata: {labels: {app: api, role: backend}}
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports: [{containerPort: 80}]
---
apiVersion: v1
kind: Service
metadata:
  name: api
  namespace: backend
spec:
  selector: {app: api}
  ports: [{port: 80}]
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: db
  namespace: restricted
spec:
  replicas: 1
  selector: {matchLabels: {app: db, role: database}}
  template:
    metadata: {labels: {app: db, role: database}}
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports: [{containerPort: 80}]
---
apiVersion: v1
kind: Service
metadata:
  name: db
  namespace: restricted
spec:
  selector: {app: db}
  ports: [{port: 80}]
EOF

# 4. Apply Network Policies
echo "[4/4] Applying Network Policies..."
cat <<EOF | kubectl apply -f -
---
# Default deny all ingress in restricted namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: restricted
spec:
  podSelector: {}
  policyTypes: [Ingress]
---
# Allow backend to access db
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-to-db
  namespace: restricted
spec:
  podSelector:
    matchLabels: {app: db}
  policyTypes: [Ingress]
  ingress:
  - from:
    - namespaceSelector:
        matchLabels: {kubernetes.io/metadata.name: backend}
      podSelector:
        matchLabels: {role: backend}
    ports: [{protocol: TCP, port: 80}]
---
# Default deny all ingress in backend namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: backend
spec:
  podSelector: {}
  policyTypes: [Ingress]
---
# Allow frontend to access api
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-api
  namespace: backend
spec:
  podSelector:
    matchLabels: {app: api}
  policyTypes: [Ingress]
  ingress:
  - from:
    - namespaceSelector:
        matchLabels: {kubernetes.io/metadata.name: frontend}
      podSelector:
        matchLabels: {role: frontend}
    ports: [{protocol: TCP, port: 80}]
EOF

echo "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app=web -n frontend --timeout=300s
kubectl wait --for=condition=ready pod -l app=api -n backend --timeout=300s
kubectl wait --for=condition=ready pod -l app=db -n restricted --timeout=300s

echo ""
echo "=== Demo Complete ==="
echo "Architecture:"
echo "  frontend/web --> backend/api --> restricted/db"
echo ""
echo "Network Policies:"
echo "  - restricted namespace: deny all, allow only backend"
echo "  - backend namespace: deny all, allow only frontend"
echo ""
echo "Run ./netpol-test.sh to verify policies"

# netpol-setup.sh - Creates Autopilot cluster with:
# 3 namespaces: frontend, backend, restricted
# Test pods in each namespace (web, api, db)
# Network policies enforcing: frontend -> backend -> restricted flow
# netpol-test.sh - Runs 4 tests:
# Test 1: frontend -> backend (allowed)
# Test 2: frontend -> restricted (blocked)
# Test 3: backend -> restricted (allowed)
# Test 4: restricted -> backend (blocked)
# netpol-cleanup.sh - Deletes the cluster
# Run:
# ./netpol-setup.sh   # Create demo
# ./netpol-test.sh    # Verify policies
# ./netpol-cleanup.sh # Clean up

# GKE Autopilot clusters have Dataplane V2 (eBPF/Cilium) enabled by default. No additional flags needed.
# The command gcloud container clusters create-auto automatically provisions Dataplane V2, which provides:
# eBPF-based network policy enforcement
# Better performance than iptables
# Native support for Kubernetes NetworkPolicy