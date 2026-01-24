#!/bin/bash
set -e

PROJECT_ID=$(gcloud config get-value project)
REGION="asia-east2"
ZONE="asia-east2-a"
CLUSTER_NAME="binauth-demo"
ATTESTOR_ID="demo-attestor"
NOTE_ID="demo-attestor-note"
KMS_KEYRING="binauth-keyring"
KMS_KEY="binauth-key"

echo "=== Binary Authorization Demo ==="

# 1. Enable APIs
echo "[1/8] Enabling APIs..."
gcloud services enable container.googleapis.com binaryauthorization.googleapis.com containeranalysis.googleapis.com cloudkms.googleapis.com artifactregistry.googleapis.com cloudbuild.googleapis.com --quiet

# 2. Grant Cloud Build permissions
echo "[2/8] Granting Cloud Build permissions..."
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com" \
    --role="roles/artifactregistry.writer" --quiet
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com" \
    --role="roles/storage.admin" --quiet

# 3. Create Artifact Registry
echo "[3/8] Creating Artifact Registry..."
if ! gcloud artifacts repositories describe binauth-repo --location=$REGION &>/dev/null; then
    gcloud artifacts repositories create binauth-repo --repository-format=docker --location=$REGION
fi

# 4. Create KMS key for signing
echo "[4/8] Creating KMS key..."
if ! gcloud kms keyrings describe $KMS_KEYRING --location=$REGION &>/dev/null; then
    gcloud kms keyrings create $KMS_KEYRING --location=$REGION
fi
if ! gcloud kms keys describe $KMS_KEY --keyring=$KMS_KEYRING --location=$REGION &>/dev/null; then
    gcloud kms keys create $KMS_KEY --keyring=$KMS_KEYRING --location=$REGION --purpose=asymmetric-signing --default-algorithm=ec-sign-p256-sha256
fi
# Ensure key version is enabled
KEY_STATE=$(gcloud kms keys versions describe 1 --key=$KMS_KEY --keyring=$KMS_KEYRING --location=$REGION --format='value(state)' 2>/dev/null || echo "")
if [ "$KEY_STATE" = "DESTROY_SCHEDULED" ] || [ "$KEY_STATE" = "DESTROYED" ]; then
    echo "Restoring KMS key version..."
    gcloud kms keys versions restore 1 --key=$KMS_KEY --keyring=$KMS_KEYRING --location=$REGION
fi
if [ "$KEY_STATE" = "DISABLED" ]; then
    echo "Enabling KMS key version..."
    gcloud kms keys versions enable 1 --key=$KMS_KEY --keyring=$KMS_KEYRING --location=$REGION
fi

# 5. Create Container Analysis Note
echo "[5/8] Creating Attestor Note..."
cat > /tmp/note.json <<EOF
{"attestation":{"hint":{"human_readable_name":"Demo Attestor Note"}}}
EOF
curl -s -X POST "https://containeranalysis.googleapis.com/v1/projects/$PROJECT_ID/notes?noteId=$NOTE_ID" \
    -H "Authorization: Bearer $(gcloud auth print-access-token)" \
    -H "Content-Type: application/json" \
    -d @/tmp/note.json || true

# 6. Create Attestor
echo "[6/8] Creating Attestor..."
if ! gcloud container binauthz attestors describe $ATTESTOR_ID --project=$PROJECT_ID &>/dev/null; then
    gcloud container binauthz attestors create $ATTESTOR_ID \
        --attestation-authority-note=$NOTE_ID \
        --attestation-authority-note-project=$PROJECT_ID
fi
gcloud container binauthz attestors public-keys add \
    --attestor=$ATTESTOR_ID \
    --keyversion-project=$PROJECT_ID \
    --keyversion-location=$REGION \
    --keyversion-keyring=$KMS_KEYRING \
    --keyversion-key=$KMS_KEY \
    --keyversion=1 2>/dev/null || true

# 7. Create GKE cluster with Binary Authorization
echo "[7/8] Creating GKE Autopilot cluster with Binary Authorization..."
if ! gcloud container clusters describe $CLUSTER_NAME --region=$REGION &>/dev/null; then
    gcloud container clusters create-auto $CLUSTER_NAME \
        --region=$REGION \
        --binauthz-evaluation-mode=PROJECT_SINGLETON_POLICY_ENFORCE
fi
gcloud container clusters get-credentials $CLUSTER_NAME --region=$REGION

# 8. Configure Binary Authorization Policy
echo "[8/8] Configuring Binary Authorization Policy..."
cat > /tmp/policy.yaml <<EOF
defaultAdmissionRule:
  evaluationMode: REQUIRE_ATTESTATION
  enforcementMode: ENFORCED_BLOCK_AND_AUDIT_LOG
  requireAttestationsBy:
  - projects/$PROJECT_ID/attestors/$ATTESTOR_ID
globalPolicyEvaluationMode: ENABLE
EOF
gcloud container binauthz policy import /tmp/policy.yaml --project=$PROJECT_ID

echo ""
echo "=== Setup Complete ==="
echo "Attestor: $ATTESTOR_ID"
echo "Cluster: $CLUSTER_NAME (Binary Authorization enabled)"
echo ""
echo "Run ./binauth-test.sh to test the policy"
