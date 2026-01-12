#!/bin/bash

# Configuration
PROJECT_ID="advgke"
REGION_BLACK="asia-east1"   # Mapping asia-east-1 subnet to Taiwan
REGION_WHITE="asia-east2"   # Mapping asia-east-2 subnet to Hong Kong
ZONE_BLACK="${REGION_BLACK}-a"
ZONE_WHITE="${REGION_WHITE}-a"

echo "=== Starting Setup for Project: $PROJECT_ID ==="

# 1. Create Networks (Custom Mode)
echo "Creating VPCs..."
gcloud compute networks create vpc-black --subnet-mode=custom --project=$PROJECT_ID
gcloud compute networks create vpc-white --subnet-mode=custom --project=$PROJECT_ID

# 2. Create Subnets
# Note: You specified asia-east-1 subnet in vpc-black (10.140.0.0)
# and asia-east-2 subnet in vpc-white (10.170.0.0)
echo "Creating Subnets..."
gcloud compute networks subnets create asia-east-1 \
    --network=vpc-black \
    --region=$REGION_BLACK \
    --range=10.140.0.0/20 \
    --project=$PROJECT_ID

gcloud compute networks subnets create asia-east-2 \
    --network=vpc-white \
    --region=$REGION_WHITE \
    --range=10.170.0.0/20 \
    --project=$PROJECT_ID

# 3. Create Firewall Rules (Allow All Traffic for simplicity)
echo "Creating Firewall Rules..."
gcloud compute firewall-rules create allow-all-black \
    --network=vpc-black \
    --allow=all \
    --source-ranges=0.0.0.0/0 \
    --project=$PROJECT_ID

gcloud compute firewall-rules create allow-all-white \
    --network=vpc-white \
    --allow=all \
    --source-ranges=0.0.0.0/0 \
    --project=$PROJECT_ID

# 4. Create VPC Peering (Both Directions)
echo "Creating VPC Peering..."
gcloud compute networks peerings create peer-black-to-white \
    --network=vpc-black \
    --peer-network=vpc-white \
    --auto-create-routes \
    --project=$PROJECT_ID

gcloud compute networks peerings create peer-white-to-black \
    --network=vpc-white \
    --peer-network=vpc-black \
    --auto-create-routes \
    --project=$PROJECT_ID

# 5. Create VMs
echo "Creating Virtual Machines..."
gcloud compute instances create vm-black \
    --network=vpc-black \
    --subnet=asia-east-1 \
    --zone=$ZONE_BLACK \
    --machine-type=e2-micro \
    --project=$PROJECT_ID

gcloud compute instances create vm-white \
    --network=vpc-white \
    --subnet=asia-east-2 \
    --zone=$ZONE_WHITE \
    --machine-type=e2-micro \
    --project=$PROJECT_ID

# 6. Test Connectivity (Ping)
echo "Waiting 45s for VMs to initialize..."
sleep 45

# Retrieve Internal IP of vm-white
IP_WHITE=$(gcloud compute instances describe vm-white --zone=$ZONE_WHITE --format='get(networkInterfaces[0].networkIP)' --project=$PROJECT_ID)

echo "Testing Connectivity: Pinging $IP_WHITE (vm-white) from vm-black..."
# Note: This might prompt for SSH key generation if not present
gcloud compute ssh vm-black --zone=$ZONE_BLACK --project=$PROJECT_ID --command="ping -c 4 $IP_WHITE"

echo "=== Setup Complete ==="
