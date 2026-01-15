#!/bin/bash
set -e

CLUSTER_NAME="my-cluster"
ZONE="us-central1-a"

# Add new node pool with different machine type
gcloud container node-pools create pool-2 \
  --cluster $CLUSTER_NAME \
  --zone $ZONE \
  --num-nodes 1 \
  --machine-type e2-medium

echo "New node added"
kubectl get nodes
