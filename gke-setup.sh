#!/bin/bash
set -e

CLUSTER_NAME="my-cluster"
ZONE="us-central1-a"
PROJECT_ID=$(gcloud config get-value project)

# Create GKE cluster with 2 nodes
gcloud container clusters create $CLUSTER_NAME \
  --zone $ZONE \
  --num-nodes 2 \
  --machine-type e2-small

# Get credentials
gcloud container clusters get-credentials $CLUSTER_NAME --zone $ZONE

# Deploy nginx1 with 2 replicas spread across nodes
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx1
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx1
  template:
    metadata:
      labels:
        app: nginx1
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels:
                app: nginx1
            topologyKey: kubernetes.io/hostname
      containers:
      - name: nginx
        image: nginx:alpine
EOF

# Deploy nginx2 with 2 replicas spread across nodes
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx2
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx2
  template:
    metadata:
      labels:
        app: nginx2
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels:
                app: nginx2
            topologyKey: kubernetes.io/hostname
      containers:
      - name: nginx
        image: nginx:alpine
EOF

echo "Cluster created with nginx1 and nginx2 deployed"
kubectl get nodes
kubectl get pods -o wide

kubectl get pods -o wide --sort-by=.spec.nodeName