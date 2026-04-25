#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

AWS_REGION="us-east-1"
NAMESPACE="real-time-platform"
ARGOCD_NS="argocd"

echo "==> Provisioning infrastructure with Terraform"
cd "$PROJECT_ROOT/terraform"
terraform init

# Stage 1: core networking, EKS, ECR — no Helm releases
echo "==> Stage 1: Core infrastructure"
terraform apply -auto-approve \
  -target=module.networking \
  -target=module.eks \
  -target=module.ecr

# Stage 2: cluster add-ons that need a running cluster
echo "==> Stage 2: Cluster add-ons"
terraform apply -auto-approve \
  -target=module.argocd \
  -target=module.redis

# Stage 3: Kafka (isolated, sequential)
echo "==> Stage 3: Kafka"
terraform apply -auto-approve \
  -target=module.kafka

# Stage 4: everything else
echo "==> Stage 4: Remaining resources"
terraform apply -auto-approve

echo "==> Configuring kubectl"
CLUSTER_NAME=$(terraform output -raw cluster_name)
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"

echo "==> Waiting for EKS nodes to be ready"
kubectl wait node --all --for=condition=Ready --timeout=300s

echo "==> Waiting for Strimzi operator to be ready"
kubectl wait deployment/strimzi-cluster-operator \
  --for=condition=available \
  --timeout=300s \
  -n kafka

echo "==> Waiting for Kafka cluster to be ready"
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

echo "==> Triggering ArgoCD hard refresh"
kubectl annotate application real-time-platform \
  -n "$ARGOCD_NS" \
  argocd.argoproj.io/refresh=hard \
  --overwrite

echo "==> Waiting for application pods to be ready"
kubectl wait deployment --all \
  --for=condition=available \
  --timeout=300s \
  -n "$NAMESPACE"

echo ""
echo "Deployment complete."
echo "Run 'make argocd-ui' to open the ArgoCD dashboard."
echo "Run 'make port-forward' to access services locally."