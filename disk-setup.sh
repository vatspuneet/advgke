#!/bin/bash
set -e

PROJECT_ID=$(gcloud config get-value project)
REGION="us-central1"
CLUSTER_NAME="storage-autopilot"

echo "Creating GKE Autopilot cluster (skip if exists)..."
gcloud container clusters create-auto $CLUSTER_NAME \
  --region=$REGION \
  --project=$PROJECT_ID || true

echo "Getting cluster credentials..."
gcloud container clusters get-credentials $CLUSTER_NAME --region=$REGION

echo "Creating PVC..."
kubectl apply -f disk-pvc.yaml

echo "Deploying pod..."
kubectl apply -f disk-pod.yaml

echo "Waiting for pod to be ready..."
kubectl wait --for=condition=Ready pod/disk-pod1 --timeout=300s

echo "Setup complete!"
