#!/bin/bash
set -e

ZONE="us-central1-a"
FILESTORE_NAME="filestore-demo"

echo "Deleting pods and PVC..."
kubectl delete -f filestore-pods.yaml --ignore-not-found
kubectl delete -f filestore-pvc.yaml --ignore-not-found
kubectl delete -f filestore-pv.yaml --ignore-not-found

echo "Deleting Filestore..."
gcloud filestore instances delete $FILESTORE_NAME --zone=$ZONE --quiet

echo "Cleanup complete!"
