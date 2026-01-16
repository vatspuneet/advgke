#!/bin/bash
set -e

CLUSTER_NAME="autopilot-cluster"
REGION="us-central1"

# Create Autopilot cluster
gcloud container clusters create-auto $CLUSTER_NAME \
  --region $REGION

# Get credentials
gcloud container clusters get-credentials $CLUSTER_NAME --region $REGION

# Deploy php-apache for HPA demo
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: php-apache
spec:
  replicas: 1
  selector:
    matchLabels:
      app: php-apache
  template:
    metadata:
      labels:
        app: php-apache
    spec:
      containers:
      - name: php-apache
        image: registry.k8s.io/hpa-example
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 200m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
---
apiVersion: v1
kind: Service
metadata:
  name: php-apache
spec:
  selector:
    app: php-apache
  ports:
  - port: 80
EOF

# Wait for deployment
kubectl rollout status deployment/php-apache

# Create HPA
kubectl autoscale deployment php-apache --cpu-percent=50 --min=1 --max=10

echo "Setup complete. Run load test with:"
echo "kubectl run -i --tty load-generator --rm --image=busybox:1.28 --restart=Never -- /bin/sh -c 'while sleep 0.01; do wget -q -O- http://php-apache; done'"
echo ""
echo "Monitor HPA with: kubectl get hpa php-apache --watch"
kubectl get hpa
kubectl get pods

# kubectl run -i --tty load-generator --rm --image=busybox:1.28 --restart=Never -- /bin/sh -c 'while sleep 0.01; do wget -q -O- http://php-apache; done'
# kubectl get hpa php-apache --watch

# HPA scales down after a stabilization window of 5 minutes by default. This prevents flapping (rapid scale up/down cycles).
# Af ter you stop the load generator:
# CPU usage drops
# HPA waits 5 minutes (stabilization period)
# Then gradually reduces replicas