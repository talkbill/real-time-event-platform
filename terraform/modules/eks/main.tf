module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name                     = var.cluster_name
  kubernetes_version       = var.cluster_version
  vpc_id                   = var.vpc_id
  subnet_ids               = var.private_subnet_ids
  control_plane_subnet_ids = var.private_subnet_ids

  endpoint_public_access  = true
  endpoint_private_access = true

  enabled_log_types = [
    "api", "audit", "authenticator", "controllerManager", "scheduler",
  ]

  enable_cluster_creator_admin_permissions = true
  enable_irsa                              = true

  cloudwatch_log_group_retention_in_days = 30
  cloudwatch_log_group_class             = "STANDARD"

  addons = {
    coredns    = { most_recent = true }
    kube-proxy = { most_recent = true }
    vpc-cni    = { most_recent = true }
  }

  eks_managed_node_groups = {
    main = {
      name           = "${var.cluster_name}-ng"
      instance_types = var.node_instance_types
      capacity_type  = "ON_DEMAND"
      subnet_ids     = var.private_subnet_ids

      desired_size = var.desired_node_count
      min_size     = var.min_node_count
      max_size     = var.max_node_count

      update_config = { max_unavailable = 1 }

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 20
            volume_type           = "gp3"
            encrypted             = true
            delete_on_termination = true
          }
        }
      }

      metadata_options = {
        http_endpoint               = "enabled"
        http_tokens                 = "required"
        http_put_response_hop_limit = 2
      }

      iam_role_additional_policies = {
        ssm = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }

      tags = merge(var.tags, { 
        Name = "${var.cluster_name}-node" 
        "kubernetes.io/cluster/${var.cluster_name}" = "owned"
      })
    }
  }

  tags = merge(var.tags, {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  })
}