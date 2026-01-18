#!/bin/bash
set -e

PROJECT_ID=$(gcloud config get-value project)
BUCKET_NAME="${PROJECT_ID}-gcs-demo"

echo "Test 1: Pod1 creates file, Pod2 reads it"
kubectl exec gcs-pod1 -- sh -c "echo 'hello from gcs-pod1' > /data/testfile.txt"
echo "Pod1 wrote file"
sleep 2
kubectl exec gcs-pod2 -- cat /data/testfile.txt
echo "Pod2 read file successfully"

echo ""
echo "Verify file in GCS bucket:"
gcloud storage cat gs://$BUCKET_NAME/testfile.txt

echo ""
echo "Test 2: Delete pod2, recreate, verify file exists"
kubectl delete pod gcs-pod2
sed "s/BUCKET_NAME/$BUCKET_NAME/g" gcs-pods.yaml | kubectl apply -f -
kubectl wait --for=condition=Ready pod/gcs-pod2 --timeout=300s
kubectl exec gcs-pod2 -- cat /data/testfile.txt
echo "New pod2 read file successfully"

echo ""
echo "All tests passed!"
