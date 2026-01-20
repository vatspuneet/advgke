#!/bin/bash

# Configuration
PROJECT_A="advgke-proj-a"
PROJECT_B="advgke-proj-b"
REGION="asia-east1"
ZONE="${REGION}-a"

echo "=== Cross-Project VPC Peering Test ==="

# Verify peering
echo "Verifying VPC peering..."
gcloud compute networks peerings list --network=vpc-a --project=$PROJECT_A

# Get VM IPs
IP_A=$(gcloud compute instances describe vm-a --zone=$ZONE --format='value(networkInterfaces[0].networkIP)' --project=$PROJECT_A)
IP_B=$(gcloud compute instances describe vm-b --zone=$ZONE --format='value(networkInterfaces[0].networkIP)' --project=$PROJECT_B)

echo "VM IPs: vm-a=$IP_A, vm-b=$IP_B"

# Test connectivity
echo "Testing: vm-a -> vm-b..."
gcloud compute ssh vm-a --zone=$ZONE --project=$PROJECT_A --command="ping -c 3 $IP_B"

echo "Testing: vm-b -> vm-a..."
gcloud compute ssh vm-b --zone=$ZONE --project=$PROJECT_B --command="ping -c 3 $IP_A"

echo "=== Test Complete ==="
