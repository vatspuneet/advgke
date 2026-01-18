#!/bin/bash
set -e

echo "Test 1: Pod1 creates file"
kubectl exec disk-pod1 -- sh -c "echo 'hello from disk-pod1' > /data/testfile.txt"
echo "Pod1 wrote file"
kubectl exec disk-pod1 -- cat /data/testfile.txt

echo ""
echo "Test 2: Delete pod1, create pod2, verify file exists"
kubectl delete pod disk-pod1
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: disk-pod2
spec:
  containers:
    - name: app
      image: busybox
      command: ["sleep", "infinity"]
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: disk-pvc
EOF
kubectl wait --for=condition=Ready pod/disk-pod2 --timeout=300s
kubectl exec disk-pod2 -- cat /data/testfile.txt
echo "Pod2 read file successfully"

echo ""
echo "Test 3: Delete pod2, recreate pod1, verify file still exists"
kubectl delete pod disk-pod2
kubectl apply -f disk-pod.yaml
kubectl wait --for=condition=Ready pod/disk-pod1 --timeout=300s
kubectl exec disk-pod1 -- cat /data/testfile.txt
echo "Pod1 read file successfully"

echo ""
echo "All tests passed!"
