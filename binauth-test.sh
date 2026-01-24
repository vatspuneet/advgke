#!/bin/bash

PROJECT_ID=$(gcloud config get-value project)
REGION="asia-east2"
ZONE="asia-east2-a"
ATTESTOR_ID="demo-attestor"
KMS_KEYRING="binauth-keyring"
KMS_KEY="binauth-key"
AR_REPO="$REGION-docker.pkg.dev/$PROJECT_ID/binauth-repo"
TEST_IMAGE="$AR_REPO/binauth-test:v1"

echo "=== Binary Authorization Tests ==="

# Configure docker for Artifact Registry
gcloud auth configure-docker $REGION-docker.pkg.dev --quiet

# Test 1: Deploy unsigned image (should fail)
echo ""
echo "[Test 1] Deploying UNSIGNED image (SHOULD FAIL)"
kubectl run unsigned-test --image=nginx:alpine --restart=Never 2>&1 || true
kubectl delete pod unsigned-test --ignore-not-found --wait=false

# Test 2: Build and push using Cloud Build
echo ""
echo "[Test 2] Building and pushing image via Cloud Build..."
BUILD_DIR=$(mktemp -d)
cat > $BUILD_DIR/Dockerfile <<EOF
FROM nginx:alpine
RUN echo "Signed image" > /usr/share/nginx/html/index.html
EOF
gcloud builds submit $BUILD_DIR --tag $TEST_IMAGE --quiet
rm -rf $BUILD_DIR

# Get image digest
DIGEST=$(gcloud artifacts docker images describe $TEST_IMAGE --format='get(image_summary.digest)')
IMAGE_PATH="$AR_REPO/binauth-test@$DIGEST"

echo "Creating attestation for: $IMAGE_PATH"
gcloud beta container binauthz attestations sign-and-create \
    --artifact-url=$IMAGE_PATH \
    --attestor=$ATTESTOR_ID \
    --attestor-project=$PROJECT_ID \
    --keyversion-project=$PROJECT_ID \
    --keyversion-location=$REGION \
    --keyversion-keyring=$KMS_KEYRING \
    --keyversion-key=$KMS_KEY \
    --keyversion=1

# Test 3: Deploy signed image (should succeed)
echo ""
echo "[Test 3] Deploying SIGNED image (SHOULD SUCCEED)"
kubectl run signed-test --image=$IMAGE_PATH --restart=Never
kubectl wait --for=condition=ready pod/signed-test --timeout=120s
echo "Signed image deployed successfully!"

echo ""
echo "=== Tests Complete ==="
echo ""
echo "View Binary Authorization events:"
echo "gcloud logging read 'resource.type=\"k8s_cluster\" protoPayload.response.reason=\"VIOLATES_POLICY\"' --project=$PROJECT_ID --limit=10"
