#!/bin/bash
set -e

# Generate frontend certificate (for ingress/load balancer)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout frontend.key -out frontend.crt \
  -subj "/CN=nginx.example.com"

# Generate backend certificate (for pod)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout backend.key -out backend.crt \
  -subj "/CN=nginx-svc.default.svc.cluster.local"

# Create secrets
kubectl create secret tls frontend-tls --cert=frontend.crt --key=frontend.key --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret tls backend-tls --cert=backend.crt --key=backend.key --dry-run=client -o yaml | kubectl apply -f -

# Apply manifests
kubectl apply -f ssl2setup.yaml

echo "Deployed. Get ingress IP with: kubectl get ingress"

