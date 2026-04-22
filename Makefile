CLUSTER_NAME  ?= real-time-platform-cluster
AWS_REGION    ?= us-east-1
NAMESPACE     ?= real-time-platform
ARGOCD_NS     ?= argocd

.PHONY: help \
        terraform-init terraform-plan terraform-apply terraform-apply-auto terraform-destroy \
        kubeconfig \
        argocd-password argocd-ui \
        status logs \
        port-forward \
        load-test \
        deploy cleanup

help:
	@echo ""
	@echo "Usage: make <target>"
	@echo ""
	@echo "Terraform:"
	@echo "  terraform-init         Initialise Terraform"
	@echo "  terraform-plan         Show planned changes"
	@echo "  terraform-apply        Apply changes (interactive approval)"
	@echo "  terraform-apply-auto   Apply changes without approval (CI use)"
	@echo "  terraform-destroy      Destroy all AWS infrastructure"
	@echo ""
	@echo "Cluster:"
	@echo "  kubeconfig             Configure kubectl for the EKS cluster"
	@echo "  status                 Show pod status across all namespaces"
	@echo "  logs                   Tail logs for a service  e.g. make logs SVC=api-gateway"
	@echo ""
	@echo "ArgoCD:"
	@echo "  argocd-password        Print the ArgoCD admin password"
	@echo "  argocd-ui              Port-forward ArgoCD UI to localhost:8088"
	@echo ""
	@echo "Local access:"
	@echo "  port-forward           Port-forward all services for local testing"
	@echo "  load-test              Run 100 test events against the API"
	@echo ""
	@echo "Lifecycle:"
	@echo "  deploy                 Full provision: Terraform + wait for ArgoCD sync"
	@echo "  cleanup                Destroy everything (prompts for confirmation)"
	@echo ""

terraform-init:
	cd terraform && terraform init

terraform-plan:
	cd terraform && terraform plan

terraform-apply:
	cd terraform && terraform apply

terraform-apply-auto:
	cd terraform && terraform apply -auto-approve

terraform-destroy:
	cd terraform && terraform destroy -auto-approve

kubeconfig:
	aws eks update-kubeconfig --region $(AWS_REGION) --name $(CLUSTER_NAME)

status:
	kubectl get pods -A

logs:
	kubectl logs -f -l app=$(SVC) -n $(NAMESPACE) --all-containers

argocd-password:
	@kubectl get secret argocd-initial-admin-secret -n $(ARGOCD_NS) \
	  -o jsonpath="{.data.password}" | base64 -d && echo

argocd-ui:
	@echo "ArgoCD UI available at http://localhost:8088"
	@echo "Username: admin"
	@echo "Password: run 'make argocd-password'"
	kubectl port-forward svc/argocd-server -n $(ARGOCD_NS) 8088:80

port-forward:
	./scripts/port-forward.sh

load-test:
	./scripts/load-test.sh

deploy:
	./scripts/deploy.sh

cleanup:
	./scripts/cleanup.sh