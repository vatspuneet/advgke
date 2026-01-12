#!/bin/bash

PROJECT_ID=$(gcloud config get-value project)
REGION="asia-east1"
VPC_NAME="vpc-black"
CLUSTER_NAME="c1-black"
CERT_NAME="website-gcp-cert"

echo "=== Starting Cleanup ==="

# 1. Delete Cluster
echo "Deleting Cluster (Async)..."
gcloud container clusters delete $CLUSTER_NAME --region=$REGION --quiet --async

# 2. Delete Global Resources (Cert & IP)
echo "Deleting SSL Certificate..."
gcloud compute ssl-certificates delete $CERT_NAME --quiet || true

echo "Deleting Static IP..."
gcloud compute addresses delete web-ip-static --global --quiet || true

# 3. Wait for Cluster to vanish
echo "Waiting for cluster deletion..."
while gcloud container clusters list --filter="name=$CLUSTER_NAME" --format="value(name)" 2> /dev/null | grep -q .; do
    echo -n "."
    sleep 10
done
echo " Cluster deleted."

# 4. Network Cleanup
echo "Deleting Firewall Rules..."
gcloud compute firewall-rules delete allow-lb-health-checks --quiet || true

echo "Deleting VPC..."
gcloud compute networks delete $VPC_NAME --quiet

echo "Cleanup Complete!"
