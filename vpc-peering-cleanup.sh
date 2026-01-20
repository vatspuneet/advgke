#!/bin/bash

# Configuration
PROJECT_A="advgke-proj-a"
PROJECT_B="advgke-proj-b"
REGION="asia-east1"
ZONE="${REGION}-a"

echo "=== Cross-Project VPC Peering Cleanup ==="

# 1. Delete VMs
echo "Deleting VMs..."
gcloud compute instances delete vm-a --zone=$ZONE --project=$PROJECT_A --quiet
gcloud compute instances delete vm-b --zone=$ZONE --project=$PROJECT_B --quiet

# 2. Delete Peerings
echo "Deleting peerings..."
gcloud compute networks peerings delete peer-a-to-b --network=vpc-a --project=$PROJECT_A --quiet
gcloud compute networks peerings delete peer-b-to-a --network=vpc-b --project=$PROJECT_B --quiet

# 3. Delete Firewall Rules
echo "Deleting firewall rules..."
gcloud compute firewall-rules delete vpc-a-allow-all vpc-a-allow-ssh --project=$PROJECT_A --quiet
gcloud compute firewall-rules delete vpc-b-allow-all vpc-b-allow-ssh --project=$PROJECT_B --quiet

# 4. Delete Subnets
echo "Deleting subnets..."
gcloud compute networks subnets delete subnet-a --region=$REGION --project=$PROJECT_A --quiet
gcloud compute networks subnets delete subnet-b --region=$REGION --project=$PROJECT_B --quiet

# 5. Delete VPCs
echo "Deleting VPCs..."
gcloud compute networks delete vpc-a --project=$PROJECT_A --quiet
gcloud compute networks delete vpc-b --project=$PROJECT_B --quiet

# 6. Delete Projects
echo "Deleting projects..."
gcloud projects delete $PROJECT_A --quiet
gcloud projects delete $PROJECT_B --quiet

echo "=== Cleanup Complete ==="
