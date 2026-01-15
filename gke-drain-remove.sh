#!/bin/bash
set -e

CLUSTER_NAME="my-cluster"
ZONE="us-central1-a"

# Get the second node name from default pool
NODE_TO_DRAIN=$(kubectl get nodes -l cloud.google.com/gke-nodepool=default-pool -o jsonpath='{.items[1].metadata.name}')

echo "Draining node: $NODE_TO_DRAIN"

# Cordon and drain the node
kubectl cordon $NODE_TO_DRAIN
kubectl drain $NODE_TO_DRAIN --ignore-daemonsets --delete-emptydir-data --force

# Remove node by resizing the default pool
gcloud container clusters resize $CLUSTER_NAME \
  --zone $ZONE \
  --node-pool default-pool \
  --num-nodes 1 \
  --quiet

echo "Node removed"
kubectl get nodes
kubectl get pods -o wide


# Status Lifecycle (in order):
# Ready - Node is healthy and accepting pods
# Ready,SchedulingDisabled - Node is cordoned (kubectl cordon), no new pods scheduled but existing pods still running
# Ready,SchedulingDisabled - Draining in progress (kubectl drain), pods being evicted
# NotReady,SchedulingDisabled - Node is shutting down, kubelet stopping
# Node removed - Node object deleted from cluster