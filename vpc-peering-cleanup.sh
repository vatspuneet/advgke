#!/bin/bash

PROJECT_ID="advgke"
REGION_BLACK="asia-east1"
REGION_WHITE="asia-east2"
ZONE_BLACK="${REGION_BLACK}-a"
ZONE_WHITE="${REGION_WHITE}-a"

echo "=== Starting Cleanup for Project: $PROJECT_ID ==="

# 1. Delete VMs
echo "Deleting VMs..."
gcloud compute instances delete vm-black --zone=$ZONE_BLACK --project=$PROJECT_ID --quiet
gcloud compute instances delete vm-white --zone=$ZONE_WHITE --project=$PROJECT_ID --quiet

# 2. Delete Peering Connections
echo "Deleting Peerings..."
gcloud compute networks peerings delete peer-black-to-white --network=vpc-black --project=$PROJECT_ID --quiet
gcloud compute networks peerings delete peer-white-to-black --network=vpc-white --project=$PROJECT_ID --quiet

# 3. Delete Firewall Rules
echo "Deleting Firewall Rules..."
gcloud compute firewall-rules delete allow-all-black --project=$PROJECT_ID --quiet
gcloud compute firewall-rules delete allow-all-white --project=$PROJECT_ID --quiet
#gcloud compute firewall-rules delete allow-ssh-black --project=$PROJECT_ID --quiet
#gcloud compute firewall-rules delete allow-ssh-white --project=$PROJECT_ID --quiet

# 4. Delete Subnets
echo "Deleting Subnets..."
gcloud compute networks subnets delete asia-east-1 --region=$REGION_BLACK --project=$PROJECT_ID --quiet
gcloud compute networks subnets delete asia-east-2 --region=$REGION_WHITE --project=$PROJECT_ID --quiet

# 5. Delete Networks
echo "Deleting VPC Networks..."
gcloud compute networks delete vpc-black --project=$PROJECT_ID --quiet
gcloud compute networks delete vpc-white --project=$PROJECT_ID --quiet

echo "=== Cleanup Complete ==="
