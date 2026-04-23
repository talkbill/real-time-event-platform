variable "cluster_name"        { type = string }
variable "cluster_version"     { type = string }
variable "vpc_id"              { type = string }
variable "private_subnet_ids"  { type = list(string) }
variable "public_subnet_ids"   { type = list(string) }
variable "node_instance_types" { type = list(string) }
variable "desired_node_count"  { type = number }
variable "min_node_count"      { type = number }
variable "max_node_count"      { type = number }
variable "tags"                { type = map(string) }

variable "aws_region" {
  description = "AWS region  passed to the Load Balancer Controller"
  type        = string
}

variable "admin_role_arn" {
  description = "IAM role ARN granted cluster admin access via EKS access entry"
  type        = string
}

variable "lbc_chart_version" {
  description = "Helm chart version for AWS Load Balancer Controller"
  type        = string
  default     = "1.8.1"
}