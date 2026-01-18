#!/bin/bash
set -e

PROJECT_ID=$(gcloud config get-value project)
BUCKET_NAME="${PROJECT_ID}-gcs-demo"

echo "Test 1: Pod1 creates file, verify in GCS"
kubectl exec gcs-pod1 -- sh -c "echo 'hello from gcs-pod1' > /data/testfile.txt"
echo "Pod1 wrote file"
sleep 5
echo "Verify file in GCS bucket:"
gcloud storage cat gs://$BUCKET_NAME/testfile.txt

echo ""
echo "Test 2: Pod2 reads file (recreate to refresh mount)"
kubectl delete pod gcs-pod2
sed "s/BUCKET_NAME/$BUCKET_NAME/g" gcs-pods.yaml | kubectl apply -f -
kubectl wait --for=condition=Ready pod/gcs-pod2 --timeout=300s
kubectl exec gcs-pod2 -- cat /data/testfile.txt
echo "Pod2 read file successfully"

echo ""
echo "Test 3: Delete pod1, recreate, verify file persists"
kubectl delete pod gcs-pod1
sed "s/BUCKET_NAME/$BUCKET_NAME/g" gcs-pods.yaml | kubectl apply -f -
kubectl wait --for=condition=Ready pod/gcs-pod1 --timeout=300s
kubectl exec gcs-pod1 -- cat /data/testfile.txt
echo "New pod1 read file successfully"

echo ""
echo "All tests passed!"
