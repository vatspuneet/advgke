# 1. Generate the private key and certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout nginx.key -out nginx.crt \
    -subj "/CN=my-nginx.example.com/O=MyOrg"

# 2. Create the GKE Autopilot cluster in project 'advgke'
gcloud container clusters create-auto my-autopilot-cluster \
    --region us-central1 \
    --project advgke

# 3. Get authentication credentials for kubectl
gcloud container clusters get-credentials my-autopilot-cluster \
    --region us-central1 \
    --project advgke

# 4. Upload the certificate to the cluster
kubectl create secret tls nginx-tls-secret \
    --key nginx.key \
    --cert nginx.crt
