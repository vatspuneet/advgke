#!/bin/bash
set -e

CLUSTER_NAME="autopilot-cluster"
REGION="us-central1"

gcloud container clusters delete $CLUSTER_NAME --region $REGION --quiet
