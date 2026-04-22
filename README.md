# Real-Time Event-Driven Microservices Platform

An event-driven microservices platform on AWS EKS. Events are received by an API gateway, streamed through Apache Kafka, persisted to PostgreSQL, cached in Redis, and pushed live to browsers over WebSocket. Deployed via GitOps with ArgoCD.

## Architecture

| Component        | Technology                         |
|------------------|------------------------------------|
| API Gateway      | Flask (Python 3.13)                |
| Event Producer   | Python + kafka-python              |
| Stream Processor | Python + kafka-python + psycopg2   |
| WebSocket Server | Node.js 22 + ws                    |
| Message Broker   | Apache Kafka 3.7 (Strimzi, KRaft)  |
| Cache            | Redis (Bitnami Helm chart)         |
| Database         | PostgreSQL 16 (AWS RDS)            |
| Orchestration    | AWS EKS (Kubernetes 1.32)          |
| IaC              | Terraform >= 1.7                   |
| GitOps           | ArgoCD + Kustomize                 |
| CI/CD            | GitHub Actions                     |
| Monitoring       | Prometheus + Grafana + Loki        |

## How it works

```
Client → api-gateway → Kafka → stream-processor → PostgreSQL → Redis → websocket-server → Client
```

Each component is a separate microservice with a single responsibility:

- **api-gateway** — receives HTTP POST events from clients and publishes them to Kafka
- **event-producer** — background worker that generates synthetic events to keep the pipeline active without real client traffic. In production this would be removed; the api-gateway is the sole Kafka producer
- **stream-processor** — Kafka consumer that persists every event to PostgreSQL and increments per-event-type counters in Redis
- **websocket-server** — reads Redis counters every second and pushes live updates to all connected browser clients over a persistent WebSocket connection

Kafka decouples producers from consumers — the api-gateway publishes and moves on regardless of how fast the stream-processor can consume. If the processor is slow or crashes, events queue durably in Kafka and are replayed from the last committed offset on restart.

## Prerequisites

- AWS CLI configured with EKS, RDS, VPC, ECR, and IAM permissions
- Terraform >= 1.7
- kubectl
- kustomize >= 5.4
- make

## Quick Start

```bash
# 1. Copy and fill in Terraform variables
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# edit terraform.tfvars — set github_org at minimum
# sensitive variables (db_password, grafana_admin_password etc.) should be
# exported as environment variables instead of written to the file:
export TF_VAR_db_username="appuser"
export TF_VAR_db_password="yourpassword"
export TF_VAR_redis_password="yourpassword"
export TF_VAR_grafana_admin_password="yourpassword"
export TF_VAR_github_org="yourorg"

# 2. Provision all infrastructure and deploy
make deploy

# 3. Port-forward services for local access
make port-forward

# 4. Run a load test
make load-test
```

`make deploy` provisions VPC, EKS, RDS, Redis, Kafka, ArgoCD, and monitoring in one shot — then waits for ArgoCD to sync all application services to the cluster.

## Secrets

Kubernetes secrets (PostgreSQL credentials) are not stored in this repository. Before the first deploy, create the secret manually in the cluster:

```bash
kubectl create secret generic app-secrets \
  --namespace real-time-platform \
  --from-literal=POSTGRES_USER=appuser \
  --from-literal=POSTGRES_PASSWORD=yourpassword
```

Terraform also stores the RDS credentials in AWS Secrets Manager automatically at `real-time-platform-db-credentials-dev`. The production path is to replace the manual step above with the External Secrets Operator (ESO) syncing from Secrets Manager — see `kubernetes/base/secrets.yaml` for the placeholder and wiring.

## After first deploy — set the RDS hostname

```bash
# Get the RDS endpoint from Terraform output
terraform -chdir=terraform output -raw db_endpoint

# Paste it into kubernetes/overlays/dev/configmap-patch.yaml
# under POSTGRES_HOST, then commit and push — ArgoCD picks it up automatically
```

## CI/CD Pipeline

Defined in `.github/workflows/ci.yml`. All jobs run on every push to `main` and every pull request targeting `main` or `develop`. `build-and-push` only runs after lint, security-scan, and test all pass.

```
push to main
  ├── lint          ruff (Python), eslint (Node.js)
  ├── security-scan Trivy IaC scan + pip-audit
  └── test          pytest (Python services), jest (websocket-server)
        │
        └── all pass → build-and-push
              ├── builds each image and pushes to ECR (SHA-only tag, no :latest)
              ├── scans each image with Trivy — stops on HIGH/CRITICAL CVEs
              ├── updates kubernetes/overlays/dev/kustomization.yaml with new tags
              └── commits manifest [skip ci] → ArgoCD syncs to EKS
```

### Required GitHub secret

| Secret         | Description                                      |
| -------------- | ------------------------------------------------ |
| `AWS_ROLE_ARN` | IAM role ARN for GitHub Actions OIDC federation  |

## GitOps with ArgoCD

ArgoCD watches `kubernetes/overlays/dev` on `main`. When CI commits updated image tags, ArgoCD detects the change and syncs the cluster within 3 minutes — no manual `kubectl apply` needed.

```bash
# Get the ArgoCD admin password
make argocd-password

# Open the ArgoCD UI at http://localhost:8088
make argocd-ui
```

## Makefile reference

```bash
make deploy            # full provision + deploy (start here)
make cleanup           # destroy everything (prompts for confirmation)

make terraform-plan    # preview infrastructure changes
make terraform-apply   # apply changes with interactive approval
make kubeconfig        # configure kubectl for the cluster

make status            # pod status across all namespaces
make logs SVC=api-gateway  # tail logs for a specific service

make argocd-password   # print ArgoCD admin password
make argocd-ui         # port-forward ArgoCD to localhost:8088
make port-forward      # port-forward all services locally
make load-test         # fire 100 test events at the API
```

## Monitoring

Grafana, Prometheus, and Loki are deployed in the `monitoring` namespace.

```bash
kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80
# open http://localhost:3000
# username: admin
# password: the value you set for TF_VAR_grafana_admin_password
```

Prometheus is configured with `serviceMonitorSelectorNilUsesHelmValues: false` so it discovers `ServiceMonitor` resources across all namespaces, including `real-time-platform`. Loki collects logs from all pods via Promtail and is available as a datasource in Grafana.

## Cleanup

```bash
make cleanup
```

Deletes the ArgoCD Application (which cascades to all managed Kubernetes resources), waits for load balancers to deprovision, then runs `terraform destroy` to remove all AWS infrastructure.