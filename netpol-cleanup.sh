#!/bin/bash

PROJECT_ID=$(gcloud config get-value project)
REGION="us-central1"
CLUSTER_NAME="netpol-demo"

echo "=== Network Policy Demo Cleanup ==="

# Delete cluster
echo "Deleting Cluster..."
gcloud container clusters delete $CLUSTER_NAME --region=$REGION --quiet --async

# Wait for deletion
echo "Waiting for cluster deletion..."
while gcloud container clusters list --filter="name=$CLUSTER_NAME" --format="value(name)" 2>/dev/null | grep -q .; do
    echo -n "."
    sleep 10
done
echo " Done."

echo "Cleanup Complete!"
