locals {
  common_tags = merge(var.tags, {
    Project     = var.project
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "terraform"
    Module      = "eks"
  })

  create_nodegroups = var.enable_nodegroups && length(var.nodegroups) > 0
}


module "cluster" {
  source = "./cluster"

  name    = var.cluster_name
  version = var.cluster_version

  project     = var.project
  environment = var.environment
  owner       = var.owner
  tags        = local.common_tags

  vpc_id     = var.vpc_id
  subnet_ids = var.cluster_subnet_ids

  endpoint_public_access       = var.endpoint_public_access
  endpoint_public_access_cidrs = var.endpoint_public_access_cidrs
  endpoint_private_access      = var.endpoint_private_access

  cluster_log_types = var.cluster_log_types

  secrets_kms_key_arn               = var.secrets_kms_key_arn
  security_group_additional_ingress = var.security_group_additional_ingress

  enable_core_addons       = var.enable_core_addons
  addon_vpc_cni_version    = var.addon_vpc_cni_version
  addon_coredns_version    = var.addon_coredns_version
  addon_kube_proxy_version = var.addon_kube_proxy_version

  eks_admin_principal_arns = var.eks_admin_principal_arns
  eks_view_principal_arns  = var.eks_view_principal_arns
}

module "nodegroups" {
  count  = local.create_nodegroups ? 1 : 0
  source = "./nodegroups"

  cluster_name    = module.cluster.cluster_name
  cluster_version = var.cluster_version

  project     = var.project
  environment = var.environment
  owner       = var.owner
  tags        = local.common_tags

  subnet_ids = var.nodegroup_subnet_ids

  nodegroups = var.nodegroups

  depends_on = [
    module.cluster
  ]
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

resource "time_sleep" "cluster_ready" {
  depends_on = [module.cluster]

  create_duration = "30s"

  triggers = {
    cluster_name     = module.cluster.cluster_name
    cluster_endpoint = module.cluster.cluster_endpoint
    cluster_status   = module.cluster.cluster_status
  }
}

resource "terraform_data" "nodegroup_dependency" {
  count = local.create_nodegroups ? 1 : 0

  depends_on = [
    time_sleep.cluster_ready,
    module.cluster
  ]

  triggers_replace = [
    module.cluster.cluster_name,
    module.cluster.cluster_arn,
    module.cluster.oidc_provider_arn
  ]
}
