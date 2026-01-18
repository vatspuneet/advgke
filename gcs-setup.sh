#!/bin/bash
set -e

PROJECT_ID=$(gcloud config get-value project)
REGION="us-central1"
CLUSTER_NAME="storage-autopilot"
BUCKET_NAME="${PROJECT_ID}-gcs-demo"

echo "Creating GCS bucket..."
gcloud storage buckets create gs://$BUCKET_NAME --location=$REGION || true

echo "Creating GKE Autopilot cluster (skip if exists)..."
gcloud container clusters create-auto $CLUSTER_NAME \
  --region=$REGION \
  --project=$PROJECT_ID || true

echo "Getting cluster credentials..."
gcloud container clusters get-credentials $CLUSTER_NAME --region=$REGION

echo "Creating GCP service account..."
gcloud iam service-accounts create gcs-sa --display-name="GCS SA" || true

echo "Granting GCS access..."
gcloud storage buckets add-iam-policy-binding gs://$BUCKET_NAME \
  --member="serviceAccount:gcs-sa@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/storage.objectAdmin"

echo "Linking GCP SA to K8s SA via workload identity..."
gcloud iam service-accounts add-iam-policy-binding gcs-sa@$PROJECT_ID.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="serviceAccount:$PROJECT_ID.svc.id.goog[default/gcs-sa]"

echo "Creating Kubernetes service account..."
kubectl create serviceaccount gcs-sa || true
kubectl annotate serviceaccount gcs-sa \
  iam.gke.io/gcp-service-account=gcs-sa@$PROJECT_ID.iam.gserviceaccount.com --overwrite

echo "Waiting for IAM propagation..."
sleep 30

echo "Deploying pods..."
sed "s/BUCKET_NAME/$BUCKET_NAME/g" gcs-pods.yaml | kubectl apply -f -

echo "Waiting for pods to be ready..."
kubectl wait --for=condition=Ready pod/gcs-pod1 pod/gcs-pod2 --timeout=300s

echo "Setup complete!"
