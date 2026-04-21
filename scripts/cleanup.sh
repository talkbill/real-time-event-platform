#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

ARGOCD_NS="argocd"
NAMESPACE="real-time-platform"

echo "WARNING: This will delete all Kubernetes resources and destroy all AWS infrastructure."
read -rp "Type 'yes' to continue: " confirm

if [ "$confirm" != "yes" ]; then
  echo "Cancelled."
  exit 0
fi

echo "==> Deleting ArgoCD Application (triggers managed resource cleanup)"
kubectl delete application real-time-platform -n "$ARGOCD_NS" --ignore-not-found

echo "==> Waiting for application namespace to be fully deleted"
kubectl wait namespace/"$NAMESPACE" --for=delete --timeout=120s 2>/dev/null || true

echo "==> Waiting 30s for load balancers to deprovision"
sleep 30

echo "==> Destroying Terraform infrastructure"
cd "$PROJECT_ROOT/terraform"
terraform destroy -auto-approve

echo "Cleanup complete."