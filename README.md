# Real-Time Event-Driven Microservices Platform

A event-driven platform on AWS EKS with Kafka, Redis, and PostgreSQL.

## Architecture

| Component | Technology |
|-----------|-----------|
| API Gateway | Flask (Python 3.13) |
| Event Producer | Python + kafka-python |
| Stream Processor | Python + kafka-python |
| WebSocket Server | Node.js 22 + ws |
| Message Broker | Apache Kafka (Strimzi on K8s) |
| Cache | Redis |
| Database | PostgreSQL 16 (AWS RDS) |
| Orchestration | AWS EKS (Kubernetes 1.32) |
| IaC | Terraform >= 1.7 |
| GitOps | ArgoCD / Kustomize |
| CI/CD | GitHub Actions |

## Quick Start

```bash
# 1. Provision infrastructure
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# edit terraform.tfvars with your values
make terraform-init
make terraform-apply

# 2. Deploy application
make deploy-eks

# 3. Port-forward for local access
./scripts/port-forward.sh

# 4. Run a load test
./scripts/load-test.sh
```

## Cleanup

```bash
make cleanup
make terraform-destroy
```
