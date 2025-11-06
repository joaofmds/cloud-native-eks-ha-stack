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

data "aws_subnet" "nodegroups" {
  for_each = local.create_nodegroups ? { for id in var.nodegroup_subnet_ids : id => id } : {}
  id       = each.value
}

locals {
  nodegroup_public_subnet_ids = local.create_nodegroups ? [
    for subnet in data.aws_subnet.nodegroups : subnet.id
    if subnet.map_public_ip_on_launch
  ] : []
}

resource "terraform_data" "validate_nodegroup_subnets" {
  count = local.create_nodegroups ? 1 : 0

  lifecycle {
    precondition {
      condition     = length(local.nodegroup_public_subnet_ids) == 0
      error_message = "Managed node groups must be deployed into private subnets without automatic public IP assignment."
    }
  }
}

resource "aws_security_group" "nodes" {
  count = local.create_nodegroups ? 1 : 0

  name        = "${var.cluster_name}-nodes-sg"
  description = "Security group for EKS managed node groups"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-nodes-sg"
  })
}

resource "aws_security_group_rule" "nodes_ingress_vpc" {
  count             = local.create_nodegroups ? 1 : 0
  description       = "Permit intra-cluster traffic inside the VPC"
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  cidr_blocks       = [var.vpc_cidr_block]
  security_group_id = aws_security_group.nodes[0].id
}

resource "aws_security_group_rule" "nodes_ingress_lb_http" {
  count             = local.create_nodegroups && length(var.public_subnet_cidr_blocks) > 0 ? 1 : 0
  description       = "Allow HTTP traffic from load balancer subnets"
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = var.public_subnet_cidr_blocks
  security_group_id = aws_security_group.nodes[0].id
}

resource "aws_security_group_rule" "nodes_ingress_lb_https" {
  count             = local.create_nodegroups && length(var.public_subnet_cidr_blocks) > 0 ? 1 : 0
  description       = "Allow HTTPS traffic from load balancer subnets"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = var.public_subnet_cidr_blocks
  security_group_id = aws_security_group.nodes[0].id
}

resource "aws_security_group_rule" "nodes_egress_http" {
  count             = local.create_nodegroups ? 1 : 0
  description       = "Allow outbound HTTP access"
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.nodes[0].id
}

resource "aws_security_group_rule" "nodes_egress_https" {
  count             = local.create_nodegroups ? 1 : 0
  description       = "Allow outbound HTTPS access"
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.nodes[0].id
}

resource "aws_security_group_rule" "nodes_egress_dns_tcp" {
  count             = local.create_nodegroups ? 1 : 0
  description       = "Allow outbound TCP DNS lookups"
  type              = "egress"
  from_port         = 53
  to_port           = 53
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr_block]
  security_group_id = aws_security_group.nodes[0].id
}

resource "aws_security_group_rule" "nodes_egress_dns_udp" {
  count             = local.create_nodegroups ? 1 : 0
  description       = "Allow outbound UDP DNS lookups"
  type              = "egress"
  from_port         = 53
  to_port           = 53
  protocol          = "udp"
  cidr_blocks       = [var.vpc_cidr_block]
  security_group_id = aws_security_group.nodes[0].id
}

module "cluster" {
  source = "./cluster"

  name               = var.cluster_name
  kubernetes_version = var.cluster_version

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
  node_security_group_id = local.create_nodegroups ? aws_security_group.nodes[0].id : null

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
    module.cluster,
    terraform_data.validate_nodegroup_subnets,
    aws_security_group.nodes,
  ]
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

resource "aws_security_group_rule" "nodes_ingress_cluster" {
  count                    = local.create_nodegroups ? 1 : 0
  description              = "Allow Kubernetes API to reach worker nodes"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.nodes[0].id
  source_security_group_id = module.cluster.cluster_security_group_id
  depends_on               = [module.cluster]
}

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
