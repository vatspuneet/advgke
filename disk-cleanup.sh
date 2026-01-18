#!/bin/bash
set -e

echo "Deleting pods..."
kubectl delete pod disk-pod1 disk-pod2 --ignore-not-found

echo "Deleting PVC..."
kubectl delete pvc disk-pvc --ignore-not-found

echo "Cleanup complete!"
