#!/bin/bash

PROJECT_ID="advgke"
REGION_BLACK="asia-east1"
REGION_WHITE="asia-east2"

gcloud config set project $PROJECT_ID

echo "=== Starting Cleanup for Project: $PROJECT_ID ==="

# 1. Delete Clusters (Async to save time)
echo "Deleting Clusters..."
gcloud container clusters delete c1-black --region=$REGION_BLACK --project=$PROJECT_ID --quiet &
PID1=$!
gcloud container clusters delete c1-white --region=$REGION_WHITE --project=$PROJECT_ID --quiet &
PID2=$!

wait $PID1 $PID2
echo "Clusters deleted."

# 2. Delete Peerings
echo "Deleting Peerings..."
gcloud compute networks peerings delete peer-black-to-white --network=vpc-black --project=$PROJECT_ID --quiet
gcloud compute networks peerings delete peer-white-to-black --network=vpc-white --project=$PROJECT_ID --quiet

# 3. Delete Firewall Rules
echo "Deleting Firewall Rules..."
gcloud compute firewall-rules delete allow-all-black --project=$PROJECT_ID --quiet
gcloud compute firewall-rules delete allow-all-white --project=$PROJECT_ID --quiet

# 4. Delete Subnets
echo "Deleting Subnets..."
gcloud compute networks subnets delete asia-east-1 --region=$REGION_BLACK --project=$PROJECT_ID --quiet
gcloud compute networks subnets delete asia-east-2 --region=$REGION_WHITE --project=$PROJECT_ID --quiet

# 5. Delete VPCs
echo "Deleting Networks..."
gcloud compute networks delete vpc-black --project=$PROJECT_ID --quiet
gcloud compute networks delete vpc-white --project=$PROJECT_ID --quiet

echo "=== Cleanup Complete ==="
