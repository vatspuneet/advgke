#!/bin/bash
set -e

PROJECT_ID=$(gcloud config get-value project)
REGION="me-central1"
ZONE="me-central1-a"
CLUSTER_NAME="security-cluster"

# STEP 1: Get credentials for existing cluster (cluster creation commented out)
echo "Getting credentials for existing cluster..."
# gcloud container clusters create $CLUSTER_NAME \
#   --region=$REGION \
#   --project=$PROJECT_ID \
#   --num-nodes=1 \
#   --workload-pool=$PROJECT_ID.svc.id.goog \
#   --enable-dataplane-v2 \
#   --enable-dataplane-v2-flow-observability || true

gcloud container clusters get-credentials $CLUSTER_NAME --zone=$ZONE

# STEP 2: Create namespaces to isolate team1 (app1) and team2 (app2)
echo "Creating namespaces..."
kubectl create namespace app1 || true
kubectl create namespace app2 || true

# STEP 3: Create RBAC Roles defining permissions for support (read-only) and developer (edit)
echo "Creating RBAC roles..."
kubectl apply -f - <<EOF
# Support role - read-only access
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: support-role
  namespace: app1
rules:
- apiGroups: ["", "apps"]
  resources: ["pods", "deployments", "services", "configmaps"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: support-role
  namespace: app2
rules:
- apiGroups: ["", "apps"]
  resources: ["pods", "deployments", "services", "configmaps"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get", "list"]
---
# Developer role - edit access
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer-role
  namespace: app1
rules:
- apiGroups: ["", "apps"]
  resources: ["pods", "deployments", "deployments/scale", "services", "configmaps", "secrets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["pods/log", "pods/exec"]
  verbs: ["get", "list", "create"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer-role
  namespace: app2
rules:
- apiGroups: ["", "apps"]
  resources: ["pods", "deployments", "deployments/scale", "services", "configmaps", "secrets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["pods/log", "pods/exec"]
  verbs: ["get", "list", "create"]
EOF

# STEP 4: Create GCP service accounts (one per team role) for Workload Identity
echo "Creating GCP service accounts..."
for SA in team1-support team1-dev team2-support team2-dev; do
  gcloud iam service-accounts create $SA --display-name="$SA" || true
done

# STEP 5: Create K8s service accounts in each namespace
echo "Creating K8s service accounts for team1..."
kubectl create serviceaccount team1-support -n app1 || true
kubectl create serviceaccount team1-dev -n app1 || true

# Create K8s service accounts in app2
echo "Creating K8s service accounts for team2..."
kubectl create serviceaccount team2-support -n app2 || true
kubectl create serviceaccount team2-dev -n app2 || true

# STEP 6: Annotate K8s SAs to map them to corresponding GCP SAs
echo "Linking K8s SAs to GCP SAs..."
kubectl annotate serviceaccount team1-support -n app1 \
  iam.gke.io/gcp-service-account=team1-support@${PROJECT_ID}.iam.gserviceaccount.com --overwrite
kubectl annotate serviceaccount team1-dev -n app1 \
  iam.gke.io/gcp-service-account=team1-dev@${PROJECT_ID}.iam.gserviceaccount.com --overwrite
kubectl annotate serviceaccount team2-support -n app2 \
  iam.gke.io/gcp-service-account=team2-support@${PROJECT_ID}.iam.gserviceaccount.com --overwrite
kubectl annotate serviceaccount team2-dev -n app2 \
  iam.gke.io/gcp-service-account=team2-dev@${PROJECT_ID}.iam.gserviceaccount.com --overwrite

# STEP 7: Grant workloadIdentityUser role so K8s SA can impersonate GCP SA
echo "Binding Workload Identity..."
gcloud iam service-accounts add-iam-policy-binding team1-support@${PROJECT_ID}.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="serviceAccount:${PROJECT_ID}.svc.id.goog[app1/team1-support]" || true
gcloud iam service-accounts add-iam-policy-binding team1-dev@${PROJECT_ID}.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="serviceAccount:${PROJECT_ID}.svc.id.goog[app1/team1-dev]" || true
gcloud iam service-accounts add-iam-policy-binding team2-support@${PROJECT_ID}.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="serviceAccount:${PROJECT_ID}.svc.id.goog[app2/team2-support]" || true
gcloud iam service-accounts add-iam-policy-binding team2-dev@${PROJECT_ID}.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="serviceAccount:${PROJECT_ID}.svc.id.goog[app2/team2-dev]" || true

# STEP 8: Create RoleBindings to assign Roles to K8s ServiceAccounts
echo "Creating RoleBindings..."
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: team1-support-binding
  namespace: app1
subjects:
- kind: ServiceAccount
  name: team1-support
  namespace: app1
roleRef:
  kind: Role
  name: support-role
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: team1-dev-binding
  namespace: app1
subjects:
- kind: ServiceAccount
  name: team1-dev
  namespace: app1
roleRef:
  kind: Role
  name: developer-role
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: team2-support-binding
  namespace: app2
subjects:
- kind: ServiceAccount
  name: team2-support
  namespace: app2
roleRef:
  kind: Role
  name: support-role
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: team2-dev-binding
  namespace: app2
subjects:
- kind: ServiceAccount
  name: team2-dev
  namespace: app2
roleRef:
  kind: Role
  name: developer-role
  apiGroup: rbac.authorization.k8s.io
EOF

# STEP 9: Deploy sample apps (nginx) in each namespace for testing
echo "Deploying apps..."
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app1
  namespace: app1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: app1
  template:
    metadata:
      labels:
        app: app1
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app2
  namespace: app2
spec:
  replicas: 1
  selector:
    matchLabels:
      app: app2
  template:
    metadata:
      labels:
        app: app2
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
---
apiVersion: v1
kind: Service
metadata:
  name: app1-svc
  namespace: app1
spec:
  selector:
    app: app1
  ports:
  - port: 80
---
apiVersion: v1
kind: Service
metadata:
  name: app2-svc
  namespace: app2
spec:
  selector:
    app: app2
  ports:
  - port: 80
EOF

echo "Waiting for pods..."
kubectl wait --for=condition=Ready pod -l app=app1 -n app1 --timeout=300s
kubectl wait --for=condition=Ready pod -l app=app2 -n app2 --timeout=300s

echo "Setup complete!"
kubectl get pods -n app1
kubectl get pods -n app2
