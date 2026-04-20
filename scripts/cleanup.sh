#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "WARNING: This will destroy all resources"
read -p "Type 'yes' to continue: " confirm

if [ "$confirm" != "yes" ]; then
  echo "Cancelled."
  exit 0
fi

echo "Deleting Kubernetes resources..."
kubectl delete -k "$PROJECT_ROOT/kubernetes/overlays/dev" --ignore-not-found

echo "Destroying Terraform resources..."
cd "$PROJECT_ROOT/terraform"
terraform destroy -auto-approve

echo "Cleanup complete!"
