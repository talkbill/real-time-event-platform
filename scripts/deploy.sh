#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "Starting deployment of Real-Time Event Platform"

cd "$PROJECT_ROOT/terraform"
echo "Initializing Terraform..."
terraform init

echo "Planning Terraform changes..."
terraform plan

echo "Applying Terraform configuration..."
terraform apply -auto-approve

echo "Waiting for EKS cluster to be ready..."
sleep 60

echo "Configuring kubectl..."
aws eks update-kubeconfig --region us-east-1 --name real-time-platform-cluster

echo "Waiting for Kafka operator to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/strimzi-cluster-operator -n kafka

echo "Waiting for Kafka cluster to be ready..."
sleep 30

echo "Deploying application..."
kubectl apply -k "$PROJECT_ROOT/kubernetes/overlays/dev"

echo "Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment -n real-time-platform --all

echo "Deployment complete!"
