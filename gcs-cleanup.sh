#!/bin/bash
set -e

PROJECT_ID=$(gcloud config get-value project)
REGION="us-central1"
CLUSTER_NAME="gcs-autopilot"
BUCKET_NAME="${PROJECT_ID}-gcs-demo"

echo "Deleting pods..."
kubectl delete pod gcs-pod1 gcs-pod2 --ignore-not-found

echo "Deleting service account..."
kubectl delete serviceaccount gcs-sa --ignore-not-found

echo "Deleting GKE cluster..."
gcloud container clusters delete $CLUSTER_NAME --region=$REGION --quiet

echo "Deleting GCS bucket..."
gcloud storage rm -r gs://$BUCKET_NAME

echo "Cleanup complete!"
