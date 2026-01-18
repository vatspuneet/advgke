#!/bin/bash
set -e

echo "Test 1: Pod1 creates file, Pod2 reads it"
kubectl exec pod1 -- sh -c "echo 'hello from pod1' > /data/testfile.txt"
echo "Pod1 wrote file"
kubectl exec pod2 -- cat /data/testfile.txt
echo "Pod2 read file successfully"

echo ""
echo "Test 2: Delete pod2, recreate, verify file exists"
kubectl delete pod pod2
kubectl apply -f filestore-pods.yaml
kubectl wait --for=condition=Ready pod/pod2 --timeout=300s
kubectl exec pod2 -- cat /data/testfile.txt
echo "New pod2 read file successfully"

echo ""
echo "All tests passed!"


#sudo mount FILESTORE_IP:/vol1 /mnt
#s /mnt
#cat /mnt/testfile.txt