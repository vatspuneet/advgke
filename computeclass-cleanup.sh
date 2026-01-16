#!/bin/bash
set -e

CLUSTER_NAME="cc-cluster"
ZONE="us-central1-a"

gcloud container clusters delete $CLUSTER_NAME --zone $ZONE --quiet
