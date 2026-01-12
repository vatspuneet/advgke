#!/bin/bash

# --- Configuration (Must match setup script) ---
PROJECT_ID=$(gcloud config get-value project)

VPC_BLACK="vpc-black"
SUBNET_BLACK_NAME="asia-east-1"
REGION_BLACK="asia-east1"
ZONE_BLACK="asia-east1-a"

VPC_WHITE="vpc-white"
SUBNET_WHITE_NAME="asia-east-2"
REGION_WHITE="asia-east2"
ZONE_WHITE="asia-east2-a"

echo "=== Starting Cleanup for Project: $PROJECT_ID ==="

# 1. Delete Clusters (Async to save time)
echo "[1/4] Deleting Clusters..."

gcloo "Deleting Clusters..."
gcloud container clusters delete c1s-black --zone=$ZONE_BLACK --project=$PROJECT_ID --quiet &
PID1=$!
gcloud container clusters delete c1s-white --zone=$ZONE_WHITE --project=$PROJECT_ID --quiet &
PID2=$!

wait $PID1 $PID2
echo "Clusters deleted."


# 2. Delete Firewall Rules
echo "[2/4] Deleting Firewall Rules..."
gcloud compute firewall-rules delete allow-all-black --quiet
gcloud compute firewall-rules delete allow-all-white --quiet

# 3. Delete Subnets
echo "[3/4] Deleting Subnets..."
# Note: Peering usually prevents network deletion, but subnets can often be removed if empty. 
# If peering locks subnets, we delete peering first (handled implicitly by network deletion usually, but safer to do explicit if stuck).
gcloud compute networks subnets delete $SUBNET_BLACK_NAME --region=$REGION_BLACK --quiet
gcloud compute networks subnets delete $SUBNET_WHITE_NAME --region=$REGION_WHITE --quiet

# 4. Delete VPCs
echo "[4/4] Deleting VPCs..."
gcloud compute networks delete $VPC_BLACK --quiet
gcloud compute networks delete $VPC_WHITE --quiet

echo "Cleanup Complete!"
