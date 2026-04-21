#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

AWS_REGION="us-east-1"
CLUSTER_NAME="real-time-platform-cluster"
NAMESPACE="real-time-platform"
ARGOCD_NS="argocd"

echo "==> Provisioning infrastructure with Terraform"
cd "$PROJECT_ROOT/terraform"
terraform init
terraform apply -auto-approve

echo "==> Configuring kubectl"
# Read cluster name from Terraform output so it stays in sync with variables
CLUSTER_NAME=$(terraform output -raw cluster_name)
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"

echo "==> Waiting for EKS nodes to be ready"
# poll the actual node API rather than sleeping a fixed duration
kubectl wait node --all --for=condition=Ready --timeout=300s

echo "==> Waiting for Strimzi operator to be ready"
kubectl wait deployment/strimzi-cluster-operator \
  --for=condition=available \
  --timeout=300s \
  -n kafka

echo "==> Waiting for Kafka cluster to be ready"
# Strimzi sets a Ready condition on the Kafka CR when brokers are up
kubectl wait kafka/event-cluster \
  --for=condition=Ready \
  --timeout=600s \
  -n kafka

echo "==> Waiting for Redis to be ready"
kubectl wait deployment/redis-master \
  --for=condition=available \
  --timeout=180s \
  -n redis

echo "==> Waiting for ArgoCD to be ready"
kubectl wait deployment/argocd-server \
  --for=condition=available \
  --timeout=300s \
  -n "$ARGOCD_NS"

echo "==> Waiting for ArgoCD to sync the application"
# ArgoCD polls the repo every 3 minutes by default — force an immediate sync
kubectl exec -n "$ARGOCD_NS" deployment/argocd-server -- \
  argocd app sync real-time-platform --auth-token "$(
    kubectl get secret argocd-initial-admin-secret -n "$ARGOCD_NS" \
      -o jsonpath='{.data.password}' | base64 -d
  )" --server localhost:8080 --insecure 2>/dev/null || true

echo "==> Waiting for application pods to be ready"
kubectl wait deployment --all \
  --for=condition=available \
  --timeout=300s \
  -n "$NAMESPACE"

echo ""
echo "Deployment complete."
echo "Run 'make argocd-ui' to open the ArgoCD dashboard."
echo "Run 'make port-forward' to access services locally."