#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status

# --- Configuration ---
PROJECT_ID=$(gcloud config get-value project)

# Network Black Configuration
VPC_BLACK="vpc-black"
SUBNET_BLACK_NAME="asia-east-1" # As requested
REGION_BLACK="asia-east1"       # Taiwan
ZONE_BLACK="asia-east1-a"
CIDR_BLACK="10.141.0.0/20"

# Network White Configuration
VPC_WHITE="vpc-white"
SUBNET_WHITE_NAME="asia-east-2" # As requested
REGION_WHITE="asia-east2"       # Hong Kong
ZONE_WHITE="asia-east2-a"
CIDR_WHITE="10.171.0.0/20"

echo "=== Starting Setup for Project: $PROJECT_ID ==="

# 1. Create VPCs
echo "[1/7] Creating VPCs..."
gcloud compute networks create $VPC_BLACK --subnet-mode=custom --project=$PROJECT_ID
gcloud compute networks create $VPC_WHITE --subnet-mode=custom --project=$PROJECT_ID

# 2. Create Subnets
echo "[2/7] Creating Subnets..."
gcloud compute networks subnets create $SUBNET_BLACK_NAME \
    --network=$VPC_BLACK --region=$REGION_BLACK --range=$CIDR_BLACK --project=$PROJECT_ID

gcloud compute networks subnets create $SUBNET_WHITE_NAME \
    --network=$VPC_WHITE --region=$REGION_WHITE --range=$CIDR_WHITE --project=$PROJECT_ID

# 3. Firewall Rules & Peering
echo "[3/7] Creating Firewall Rules and VPC Peering..."
# Allow all internal traffic (and SSH/ICMP for testing)
gcloud compute firewall-rules create allow-all-black --network=$VPC_BLACK --allow=tcp,udp,icmp --source-ranges=0.0.0.0/0 --quiet
gcloud compute firewall-rules create allow-all-white --network=$VPC_WHITE --allow=tcp,udp,icmp --source-ranges=0.0.0.0/0 --quiet

# Create Peering (Must be done on both sides)
gcloud compute networks peerings create peer-black-to-white \
    --network=$VPC_BLACK --peer-network=$VPC_WHITE --auto-create-routes
gcloud compute networks peerings create peer-white-to-black \
    --network=$VPC_WHITE --peer-network=$VPC_BLACK --auto-create-routes

# 4. Create Cluster Black (c1s-black)
echo "[4/7] Creating Cluster c1s-black (this may take 5-10 mins)..."
gcloud container clusters create c1s-black \
    --zone=$ZONE_BLACK \
    --num-nodes=1 \
    --network=$VPC_BLACK \
    --subnetwork=$SUBNET_BLACK_NAME \
    --machine-type=e2-standard-2 \
    --enable-ip-alias \
    --project=$PROJECT_ID

# 5. Create Cluster White (c1s-white)
echo "[5/7] Creating Cluster c1s-white (this may take 5-10 mins)..."
gcloud container clusters create c1s-white \
    --zone=$ZONE_WHITE \
    --num-nodes=1 \
    --network=$VPC_WHITE \
    --subnetwork=$SUBNET_WHITE_NAME \
    --machine-type=e2-standard-2 \
    --enable-ip-alias \
    --project=$PROJECT_ID

# 6. Deploy Nginx
echo "[6/7] Deploying Nginx Pods..."

# Context: Black
gcloud container clusters get-credentials c1s-black --zone $ZONE_BLACK
kubectl run nginx-black --image=nginx --restart=Never
kubectl expose pod nginx-black --port=80 --type=ClusterIP

# Context: White
gcloud container clusters get-credentials c1s-white --zone $ZONE_WHITE
kubectl run nginx-white --image=nginx --restart=Never
kubectl expose pod nginx-white --port=80 --type=ClusterIP

echo "Waiting 30 seconds for pods to be running..."
sleep 30

# 7. Connectivity Test
echo "[7/7] Testing Connectivity..."

# Get Pod IPs
gcloud container clusters get-credentials c1s-black --zone $ZONE_BLACK
POD_IP_BLACK=$(kubectl get pod nginx-black -o jsonpath='{.status.podIP}')
echo "Black Pod IP: $POD_IP_BLACK"

gcloud container clusters get-credentials c1s-white --zone $ZONE_WHITE
POD_IP_WHITE=$(kubectl get pod nginx-white -o jsonpath='{.status.podIP}')
echo "White Pod IP: $POD_IP_WHITE"

echo "---------------------------------------------------"
echo "Testing: Curl from WHITE cluster -> BLACK Pod IP ($POD_IP_BLACK)"
kubectl exec nginx-white -- curl -s -m 5 $POD_IP_BLACK > /dev/null
if [ $? -eq 0 ]; then echo "✅ SUCCESS: White can reach Black"; else echo "❌ FAIL: White cannot reach Black"; fi

echo "---------------------------------------------------"
echo "Testing: Curl from BLACK cluster -> WHITE Pod IP ($POD_IP_WHITE)"
gcloud container clusters get-credentials c1s-black --zone $ZONE_BLACK
kubectl exec nginx-black -- curl -s -m 5 $POD_IP_WHITE > /dev/null
if [ $? -eq 0 ]; then echo "✅ SUCCESS: Black can reach White"; else echo "❌ FAIL: Black cannot reach White"; fi
echo "---------------------------------------------------"

echo "Setup and Tests Complete!"
