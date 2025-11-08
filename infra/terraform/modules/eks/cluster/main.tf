data "aws_caller_identity" "this" {}
data "aws_region" "this" {}

locals {
  common_tags = merge({
    ManagedBy   = "Terraform",
    Project     = var.project,
    Environment = var.environment,
    Owner       = var.owner,
  }, var.tags)
}

resource "aws_security_group" "cluster" {
  name        = "${var.name}-cluster-sg"
  description = "Cluster security group for EKS control plane"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${var.name}-cluster-sg" })
}

resource "aws_security_group_rule" "cluster_from_nodes" {
  for_each = var.enable_node_security_group_rule ? { nodes = var.node_security_group_id } : {}

  description              = "Allow worker nodes to communicate with the Kubernetes API"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.cluster.id
  source_security_group_id = each.value
}

resource "aws_security_group_rule" "cluster_extra_ingress_cidr" {
  for_each = {
    for i, r in var.security_group_additional_ingress : i => r if length(try(r.cidr_blocks, [])) > 0
  }
  security_group_id = aws_security_group.cluster.id
  type              = "ingress"
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  protocol          = each.value.protocol
  cidr_blocks       = each.value.cidr_blocks
  description       = try(each.value.description, "custom")
}

resource "aws_security_group_rule" "cluster_extra_ingress_sg" {
  for_each = {
    for i, r in var.security_group_additional_ingress : i => r if length(try(r.sg_ids, [])) > 0
  }
  security_group_id        = aws_security_group.cluster.id
  type                     = "ingress"
  from_port                = each.value.from_port
  to_port                  = each.value.to_port
  protocol                 = each.value.protocol
  source_security_group_id = each.value.sg_ids[0]
  description              = try(each.value.description, "custom")
}

resource "aws_eks_cluster" "this" {
  name                      = var.name
  version                   = var.kubernetes_version
  role_arn                  = aws_iam_role.cluster.arn
  enabled_cluster_log_types = var.cluster_log_types

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_public_access  = var.endpoint_public_access
    endpoint_private_access = var.endpoint_private_access
    public_access_cidrs     = var.endpoint_public_access ? var.endpoint_public_access_cidrs : null
    security_group_ids      = [aws_security_group.cluster.id]
  }

  dynamic "encryption_config" {
    for_each = var.secrets_kms_key_arn != null ? [1] : []
    content {
      provider {
        key_arn = var.secrets_kms_key_arn
      }
      resources = ["secrets"]
    }
  }

  lifecycle {
    ignore_changes = [access_config]
  }

  tags = merge(local.common_tags, { Name = var.name })
}

resource "aws_iam_role" "cluster" {
  name = "${var.name}-cluster-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = { Service = "eks.amazonaws.com" }
    }]
  })
  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSServicePolicy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
}

# ── OIDC provider for IRSA ────────────────────────────────────────────────────

data "aws_eks_cluster" "this" {
  name = aws_eks_cluster.this.name
}

data "tls_certificate" "oidc" {
  url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "this" {
  url             = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.oidc.certificates[0].sha1_fingerprint]
  tags            = local.common_tags
}



