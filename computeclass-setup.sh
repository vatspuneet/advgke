#!/bin/bash
set -e

CLUSTER_NAME="cc-cluster"
ZONE="us-central1-a"

# Create standard GKE cluster with 1 e2-small node and enable node auto-provisioning
gcloud container clusters create $CLUSTER_NAME \
  --zone $ZONE \
  --num-nodes 1 \
  --machine-type e2-small \
  --enable-autoprovisioning \
  --min-cpu 1 --max-cpu 10 \
  --min-memory 1 --max-memory 32 \
  --autoprovisioning-locations=$ZONE

# Get credentials
gcloud container clusters get-credentials $CLUSTER_NAME --zone $ZONE

# Deploy nginx with 2 replicas
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
EOF

# Create ComputeClass for e2-medium only
kubectl apply -f - <<EOF
apiVersion: cloud.google.com/v1
kind: ComputeClass
metadata:
  name: e2-medium-class
spec:
  priorities:
  - machineType: e2-medium
  nodePoolAutoCreation:
    enabled: true
EOF


echo "Setup complete"
kubectl get nodes -o wide
kubectl get pods -o wide
kubectl get computeclass

kubectl get events -A --sort-by='.lastTimestamp' | grep -i node