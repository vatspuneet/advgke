#!/bin/bash
set -e

PROJECT_ID=$(gcloud config get-value project)
REGION="us-central1"
ZONE="us-central1-a"
CLUSTER_NAME="storage-autopilot"
FILESTORE_NAME="filestore-demo"
NETWORK="default"

echo "Creating Filestore instance..."
gcloud filestore instances create $FILESTORE_NAME \
  --zone=$ZONE \
  --tier=BASIC_HDD \
  --file-share=name=vol1,capacity=1TB \
  --network=name=$NETWORK

echo "Creating GKE Autopilot cluster (skip if exists)..."
gcloud container clusters create-auto $CLUSTER_NAME \
  --region=$REGION \
  --project=$PROJECT_ID || true

echo "Getting cluster credentials..."
gcloud container clusters get-credentials $CLUSTER_NAME --region=$REGION

FILESTORE_IP=$(gcloud filestore instances describe $FILESTORE_NAME --zone=$ZONE --format="value(networks[0].ipAddresses[0])")
echo "Filestore IP: $FILESTORE_IP"

echo "Creating PV and PVC..."
sed "s/FILESTORE_IP/$FILESTORE_IP/g" filestore-pv.yaml | kubectl apply -f -
kubectl apply -f filestore-pvc.yaml

echo "Deploying pods..."
kubectl apply -f filestore-pods.yaml

echo "Waiting for pods to be ready..."
kubectl wait --for=condition=Ready pod/pod1 pod/pod2 --timeout=300s

echo "Setup complete!"
