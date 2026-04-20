.PHONY: help terraform-init terraform-plan terraform-apply terraform-destroy deploy-local deploy-eks cleanup

help:
	@echo "Available targets:"
	@echo "  terraform-init    - Initialize Terraform"
	@echo "  terraform-plan    - Plan Terraform changes"
	@echo "  terraform-apply   - Apply Terraform changes"
	@echo "  terraform-destroy - Destroy all resources"
	@echo "  deploy-local      - Deploy to local Kubernetes (minikube/kind)"
	@echo "  deploy-eks        - Deploy to EKS cluster"
	@echo "  cleanup           - Clean up local resources"

terraform-init:
	cd terraform && terraform init

terraform-plan:
	cd terraform && terraform plan

terraform-apply:
	cd terraform && terraform apply -auto-approve

terraform-destroy:
	cd terraform && terraform destroy -auto-approve

deploy-local:
	kubectl apply -k kubernetes/overlays/dev

deploy-eks:
	aws eks update-kubeconfig --region us-east-1 --name real-time-platform-cluster
	kubectl apply -k kubernetes/overlays/dev

cleanup:
	kubectl delete -k kubernetes/overlays/dev
