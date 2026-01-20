#!/bin/bash

# Cross-Project VPC Peering Demo (works without Organization)
# Configuration
PROJECT_A="advgke-proj-a"
PROJECT_B="advgke-proj-b"
BILLING_ACCOUNT=$(gcloud billing accounts list --format='value(name)' --limit=1)
REGION="asia-east1"
ZONE="${REGION}-a"

echo "=== Cross-Project VPC Peering Setup ==="

# 1. Create Projects
echo "Creating projects..."
gcloud projects create $PROJECT_A
gcloud projects create $PROJECT_B

# 2. Link Billing Account
echo "Linking billing account..."
gcloud billing projects link $PROJECT_A --billing-account=$BILLING_ACCOUNT
gcloud billing projects link $PROJECT_B --billing-account=$BILLING_ACCOUNT

# 3. Enable Compute API
echo "Enabling APIs..."
gcloud services enable compute.googleapis.com --project=$PROJECT_A
gcloud services enable compute.googleapis.com --project=$PROJECT_B

# 4. Create VPCs
echo "Creating VPCs..."
gcloud compute networks create vpc-a --subnet-mode=custom --project=$PROJECT_A
gcloud compute networks create vpc-b --subnet-mode=custom --project=$PROJECT_B

# 5. Create Subnets
echo "Creating subnets..."
gcloud compute networks subnets create subnet-a \
    --network=vpc-a --region=$REGION --range=10.0.1.0/24 --project=$PROJECT_A

gcloud compute networks subnets create subnet-b \
    --network=vpc-b --region=$REGION --range=10.0.2.0/24 --project=$PROJECT_B

# 6. Create Firewall Rules
echo "Creating firewall rules..."
gcloud compute firewall-rules create vpc-a-allow-all \
    --network=vpc-a --allow=tcp,udp,icmp --source-ranges=10.0.0.0/16 --project=$PROJECT_A

gcloud compute firewall-rules create vpc-a-allow-ssh \
    --network=vpc-a --allow=tcp:22 --source-ranges=0.0.0.0/0 --project=$PROJECT_A

gcloud compute firewall-rules create vpc-b-allow-all \
    --network=vpc-b --allow=tcp,udp,icmp --source-ranges=10.0.0.0/16 --project=$PROJECT_B

gcloud compute firewall-rules create vpc-b-allow-ssh \
    --network=vpc-b --allow=tcp:22 --source-ranges=0.0.0.0/0 --project=$PROJECT_B

# 7. Create VPC Peering
echo "Creating VPC peering..."
gcloud compute networks peerings create peer-a-to-b \
    --network=vpc-a --peer-project=$PROJECT_B --peer-network=vpc-b --project=$PROJECT_A

gcloud compute networks peerings create peer-b-to-a \
    --network=vpc-b --peer-project=$PROJECT_A --peer-network=vpc-a --project=$PROJECT_B

# 8. Create VMs
echo "Creating VMs..."
gcloud compute instances create vm-a \
    --network=vpc-a --subnet=subnet-a --zone=$ZONE --machine-type=e2-micro --project=$PROJECT_A

gcloud compute instances create vm-b \
    --network=vpc-b --subnet=subnet-b --zone=$ZONE --machine-type=e2-micro --project=$PROJECT_B

echo "=== Setup Complete ==="
