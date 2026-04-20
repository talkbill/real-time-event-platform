output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value     = module.eks.cluster_endpoint
  sensitive = true
}

output "kafka_bootstrap_servers" {
  value = module.kafka.kafka_bootstrap_servers
}

output "db_endpoint" {
  value = module.rds.db_endpoint
}

output "kubeconfig_command" {
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}