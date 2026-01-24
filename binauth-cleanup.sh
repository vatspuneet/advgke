#!/bin/bash

PROJECT_ID=$(gcloud config get-value project)
REGION="asia-east2"
ZONE="asia-east2-a"
CLUSTER_NAME="binauth-demo"
ATTESTOR_ID="demo-attestor"
NOTE_ID="demo-attestor-note"
KMS_KEYRING="binauth-keyring"
KMS_KEY="binauth-key"

echo "=== Binary Authorization Cleanup ==="

# Reset policy to allow all
echo "Resetting Binary Authorization policy..."
cat > /tmp/policy.yaml <<EOF
defaultAdmissionRule:
  evaluationMode: ALWAYS_ALLOW
  enforcementMode: ENFORCED_BLOCK_AND_AUDIT_LOG
globalPolicyEvaluationMode: ENABLE
EOF
gcloud container binauthz policy import /tmp/policy.yaml --project=$PROJECT_ID

# Delete cluster
# echo "Deleting cluster..."
# gcloud container clusters delete $CLUSTER_NAME --region=$REGION --quiet --async

# Delete attestor
echo "Deleting attestor..."
gcloud container binauthz attestors delete $ATTESTOR_ID --project=$PROJECT_ID --quiet 2>/dev/null || true

# Delete note
echo "Deleting note..."
curl -s -X DELETE "https://containeranalysis.googleapis.com/v1/projects/$PROJECT_ID/notes/$NOTE_ID" \
    -H "Authorization: Bearer $(gcloud auth print-access-token)" || true

# Delete container image
echo "Deleting test image..."
gcloud artifacts docker images delete $REGION-docker.pkg.dev/$PROJECT_ID/binauth-repo/binauth-test --delete-tags --quiet 2>/dev/null || true

# Note: KMS keys cannot be deleted immediately (scheduled for destruction)
echo "Scheduling KMS key destruction..."
gcloud kms keys versions destroy 1 --key=$KMS_KEY --keyring=$KMS_KEYRING --location=$REGION 2>/dev/null || true

echo ""
echo "Cleanup complete!"
