#!/bin/bash# pki with gateway api

STATIC_IP=$(gcloud compute addresses describe pki-demo-ip --global --format="value(address)")

echo "=== PKI TLS Tests ==="

echo "--- Test 1: External (Client to LB via Gateway) ---"
echo "curl -k https://$STATIC_IP"
curl -sk https://$STATIC_IP || echo "(Waiting for LB - retry in 30s)"

echo ""
echo "--- Test 2: Internal (LB to Pod TLS) ---"
kubectl run test-curl --rm -it --restart=Never --image=curlimages/curl -- curl -sk https://secure-backend:8443

echo ""
echo "=== Architecture ==="
echo "Client --[frontend-tls]--> Gateway/LB --[backend-tls]--> Pod"
