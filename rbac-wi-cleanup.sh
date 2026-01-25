#!/bin/bash

PROJECT_ID=$(gcloud config get-value project)
REGION="me-central1"
ZONE="me-central1-a"
CLUSTER_NAME="security-cluster"

echo "Deleting deployments and services..."
kubectl delete deployment app1 -n app1 --ignore-not-found
kubectl delete deployment app2 -n app2 --ignore-not-found
kubectl delete service app1-svc -n app1 --ignore-not-found
kubectl delete service app2-svc -n app2 --ignore-not-found

echo "Deleting RoleBindings..."
kubectl delete rolebinding team1-support-binding team1-dev-binding -n app1 --ignore-not-found
kubectl delete rolebinding team2-support-binding team2-dev-binding -n app2 --ignore-not-found

echo "Deleting Roles..."
kubectl delete role support-role developer-role -n app1 --ignore-not-found
kubectl delete role support-role developer-role -n app2 --ignore-not-found

echo "Deleting K8s service accounts..."
kubectl delete serviceaccount team1-support team1-dev -n app1 --ignore-not-found
kubectl delete serviceaccount team2-support team2-dev -n app2 --ignore-not-found

echo "Deleting namespaces..."
kubectl delete namespace app1 app2 --ignore-not-found

echo "Deleting GCP service accounts..."
for SA in team1-support team1-dev team2-support team2-dev; do
  gcloud iam service-accounts delete ${SA}@${PROJECT_ID}.iam.gserviceaccount.com --quiet || true
done

# echo "Deleting GKE cluster..."
# gcloud container clusters delete $CLUSTER_NAME --zone=$ZONE --quiet || true

echo "Cleanup complete!"
