#!/bin/bash
set -e

PROJECT_ID=$(gcloud config get-value project)
REGION="us-central1"
CLUSTER_NAME="gcs-autopilot"
BUCKET_NAME="${PROJECT_ID}-gcs-demo"

echo "Creating GCS bucket..."
gcloud storage buckets create gs://$BUCKET_NAME --location=$REGION || true

echo "Creating GKE Autopilot cluster..."
gcloud container clusters create-auto $CLUSTER_NAME \
  --region=$REGION \
  --project=$PROJECT_ID

echo "Getting cluster credentials..."
gcloud container clusters get-credentials $CLUSTER_NAME --region=$REGION

echo "Creating Kubernetes service account..."
kubectl create serviceaccount gcs-sa

echo "Granting GCS access to workload identity..."
gcloud storage buckets add-iam-policy-binding gs://$BUCKET_NAME \
  --member="principal://iam.googleapis.com/projects/$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')/locations/global/workloadIdentityPools/$PROJECT_ID.svc.id.goog/subject/ns/default/sa/gcs-sa" \
  --role="roles/storage.objectAdmin"

echo "Deploying pods..."
sed "s/BUCKET_NAME/$BUCKET_NAME/g" gcs-pods.yaml | kubectl apply -f -

echo "Waiting for pods to be ready..."
kubectl wait --for=condition=Ready pod/gcs-pod1 pod/gcs-pod2 --timeout=300s

echo "Setup complete!"


#./gcs-setup.sh
#./gcs-test.sh
#./gcs-cleanup.sh

# Filestore (NFS):
# Network-based access control only
# Any pod that can reach the NFS IP on the VPC network can mount it
# No identity/credential check - just IP/network connectivity
# The PV contains the NFS server IP and path, Kubernetes mounts it directly
# GCS (Cloud Storage):
# API-based access with IAM authentication
# Every request requires valid Google credentials
# GCS Fuse CSI driver needs credentials to call GCS APIs
# Workload Identity maps Kubernetes service account to GCP IAM permissions