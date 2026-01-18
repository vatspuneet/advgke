#!/bin/bash
set -e

REGION="us-central1"
ZONE="us-central1-a"
CLUSTER_NAME="filestore-autopilot"
FILESTORE_NAME="filestore-demo"

echo "Deleting pods and PVC..."
kubectl delete -f filestore-pods.yaml --ignore-not-found
kubectl delete -f filestore-pvc.yaml --ignore-not-found
kubectl delete -f filestore-pv.yaml --ignore-not-found

echo "Deleting GKE cluster..."
gcloud container clusters delete $CLUSTER_NAME --region=$REGION --quiet

echo "Deleting Filestore..."
gcloud filestore instances delete $FILESTORE_NAME --zone=$ZONE --quiet

echo "Cleanup complete!"
