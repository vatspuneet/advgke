#!/bin/bash

# Configuration
PROJECT_ID="advgke"
REGION_BLACK="asia-east1"
REGION_WHITE="asia-east2"

gcloud config set project $PROJECT_ID

# 1. Setup Networking (VPCs & Subnets)
echo "=== 1. Creating Networks and Subnets ==="
gcloud compute networks create vpc-black --subnet-mode=custom --project=$PROJECT_ID
gcloud compute networks create vpc-white --subnet-mode=custom --project=$PROJECT_ID

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

# 2. Setup VPC Peering
echo "=== 2. Creating VPC Peering ==="
gcloud compute networks peerings create peer-black-to-white \
    --network=vpc-black --peer-network=vpc-white --auto-create-routes --project=$PROJECT_ID

gcloud compute networks peerings create peer-white-to-black \
    --network=vpc-white --peer-network=vpc-black --auto-create-routes --project=$PROJECT_ID

# 3. Create Firewall Rules (Allow Pod Communication)
echo "=== 3. Creating Firewall Rules ==="
# Allowing all internal traffic to ensure Pod IP ranges are accepted
gcloud compute firewall-rules create allow-all-black \
    --network=vpc-black --allow=all --source-ranges=0.0.0.0/0 --project=$PROJECT_ID

gcloud compute firewall-rules create allow-all-white \
    --network=vpc-white --allow=all --source-ranges=0.0.0.0/0 --project=$PROJECT_ID

# 4. Create Autopilot Clusters
echo "=== 4. Creating GKE Autopilot Clusters (This takes ~5-10 mins) ==="
# Creating c1-black
gcloud container clusters create-auto c1-black \
    --region=$REGION_BLACK \
    --network=vpc-black \
    --subnetwork=asia-east-1 \
    --project=$PROJECT_ID &
PID_BLACK=$!

# Creating c1-white
gcloud container clusters create-auto c1-white \
    --region=$REGION_WHITE \
    --network=vpc-white \
    --subnetwork=asia-east-2 \
    --project=$PROJECT_ID &
PID_WHITE=$!

wait $PID_BLACK $PID_WHITE
echo "Clusters created."

# 5. Get Credentials and Deploy Nginx
echo "=== 5. Deploying Nginx Pods ==="

# Deploy to c1-black
gcloud container clusters get-credentials c1-black --region=$REGION_BLACK --project=$PROJECT_ID
kubectl run nginx-black --image=nginx --restart=Never --expose --port=80
echo "Waiting for nginx-black to be Running..."
kubectl wait --for=condition=Ready pod/nginx-black --timeout=90s

# Deploy to c1-white
gcloud container clusters get-credentials c1-white --region=$REGION_WHITE --project=$PROJECT_ID
kubectl run nginx-white --image=nginx --restart=Never --expose --port=80
echo "Waiting for nginx-white to be Running..."
kubectl wait --for=condition=Ready pod/nginx-white --timeout=90s

# 6. Connectivity Tests
gcloud container clusters get-credentials c1-black --region=$REGION_BLACK --project=$PROJECT_ID
IP_BLACK_POD=$(kubectl get pod nginx-black -o jsonpath='{.status.podIP}')
echo "Verified IP for nginx-black: $IP_BLACK_POD"

# Switch to White context to get White IP
gcloud container clusters get-credentials c1-white --region=$REGION_WHITE --project=$PROJECT_ID
IP_WHITE_POD=$(kubectl get pod nginx-white -o jsonpath='{.status.podIP}')
echo "Verified IP for nginx-white: $IP_WHITE_POD"

echo "=== 6. Testing Bi-Directional Connectivity ==="
echo "Black Pod IP: $IP_BLACK_POD"
echo "White Pod IP: $IP_WHITE_POD"

# --- Test 1: Black to White ---
# Current context is already c1-black from the previous step
echo " "
echo ">>> [Test A] Pinging from VPC-BLACK to VPC-WHITE..."
gcloud container clusters get-credentials c1-black --region=$REGION_BLACK --project=$PROJECT_ID
kubectl exec nginx-black -- curl -s -I $IP_WHITE_POD

# --- Test 2: White to Black ---
# Switch context to c1-white
echo " "
echo ">>> [Test B] Pinging from VPC-WHITE to VPC-BLACK..."
gcloud container clusters get-credentials c1-white --region=$REGION_WHITE --project=$PROJECT_ID
kubectl exec nginx-white -- curl -s -I $IP_BLACK_POD

echo " "
echo "=== Setup & All Tests Complete ==="
