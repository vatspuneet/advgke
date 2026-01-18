#!/bin/bash
set -e

PROJECT_ID=$(gcloud config get-value project)
BUCKET_NAME="${PROJECT_ID}-gcs-demo"

echo "Deleting pods..."
kubectl delete pod gcs-pod1 gcs-pod2 --ignore-not-found

echo "Deleting K8s service account..."
kubectl delete serviceaccount gcs-sa --ignore-not-found

echo "Deleting GCS bucket..."
gcloud storage rm -r gs://$BUCKET_NAME

echo "Deleting GCP service account..."
gcloud iam service-accounts delete gcs-sa@$PROJECT_ID.iam.gserviceaccount.com --quiet || true

echo "Cleanup complete!"
