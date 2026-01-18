#!/bin/bash
set -e

REGION="us-central1"
CLUSTER_NAME="storage-autopilot"

echo "Deleting GKE cluster..."
gcloud container clusters delete $CLUSTER_NAME --region=$REGION --quiet

echo "Cluster deleted!"
