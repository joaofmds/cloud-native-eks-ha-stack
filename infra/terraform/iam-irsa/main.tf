data "aws_caller_identity" "this" {}

locals {
  common_tags = merge({
    ManagedBy   = "Terraform",
    Project     = var.project,
    Environment = var.environment,
    Owner       = var.owner,
  }, var.tags)

  oidc_hostpath = replace(var.oidc_issuer_url, "https://", "")
}

resource "aws_iam_role" "generic" {
  for_each = var.generic_irsa_roles

  name = coalesce(try(each.value.name_override, null), "irsa-${each.key}")
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Action    = "sts:AssumeRoleWithWebIdentity",
      Principal = { Federated = var.oidc_provider_arn },
      Condition = {
        StringEquals = {
          "${local.oidc_hostpath}:aud" = "sts.amazonaws.com"
        },
        StringLike = {
          "${local.oidc_hostpath}:sub" = [for sa in each.value.service_accounts : "system:serviceaccount:${each.value.namespace}:${sa}"]
        }
      }
    }]
  })
  tags = local.common_tags
}

resource "aws_iam_role_policy" "generic_inline" {
  for_each = { for k, v in var.generic_irsa_roles : k => v if try(v.policy_json, null) != null }
  name     = "inline-${each.key}"
  role     = aws_iam_role.generic[each.key].id
  policy   = each.value.policy_json
}

resource "aws_iam_role_policy_attachment" "generic_attach" {
  for_each = {
    for k, v in var.generic_irsa_roles : k => { name = k, arns = v.managed_policy_arns }
    if length(try(v.managed_policy_arns, [])) > 0
  }
  role       = aws_iam_role.generic[each.value.name].name
  policy_arn = element(each.value.arns, 0)
}

locals {
  external_dns_sa = ["system:serviceaccount:${coalesce(try(var.external_dns.namespace, null), "kube-system")}:${coalesce(try(var.external_dns.service_account, null), "external-dns")}"]
}

resource "aws_iam_role" "external_dns" {
  count = var.enable_external_dns ? 1 : 0
  name  = "irsa-external-dns"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Action    = "sts:AssumeRoleWithWebIdentity",
      Principal = { Federated = var.oidc_provider_arn },
      Condition = {
        StringEquals = {
          "${local.oidc_hostpath}:aud" = "sts.amazonaws.com"
        },
        StringLike = {
          "${local.oidc_hostpath}:sub" = local.external_dns_sa
        }
      }
    }]
  })
  tags = local.common_tags
}

data "aws_iam_policy_document" "external_dns" {
  count = var.enable_external_dns ? 1 : 0

  statement {
    sid       = "ListZones"
    actions   = ["route53:ListHostedZones", "route53:ListResourceRecordSets"]
    resources = ["*"]
  }

  dynamic "statement" {
    for_each = length(try(var.external_dns.zone_ids, [])) > 0 ? var.external_dns.zone_ids : ["*"]
    content {
      sid       = "ChangeRecords-${statement.value}"
      actions   = ["route53:ChangeResourceRecordSets"]
      resources = statement.value == "*" ? ["*"] : ["arn:aws:route53:::hostedzone/${statement.value}"]
    }
  }
}

resource "aws_iam_policy" "external_dns" {
  count  = var.enable_external_dns ? 1 : 0
  name   = "external-dns-route53"
  policy = data.aws_iam_policy_document.external_dns[0].json
  tags   = local.common_tags
}

resource "aws_iam_role_policy_attachment" "external_dns_attach" {
  count      = var.enable_external_dns ? 1 : 0
  role       = aws_iam_role.external_dns[0].name
  policy_arn = aws_iam_policy.external_dns[0].arn
}

locals {
  cert_manager_sa = ["system:serviceaccount:${coalesce(try(var.cert_manager.namespace, null), "cert-manager")}:${coalesce(try(var.cert_manager.service_account, null), "cert-manager")}"]
}

data "aws_iam_policy_document" "cert_manager" {
  count = var.enable_cert_manager ? 1 : 0

  statement {
    actions   = ["route53:ListHostedZones", "route53:ListResourceRecordSets"]
    resources = ["*"]
  }

  dynamic "statement" {
    for_each = length(try(var.cert_manager.zone_ids, [])) > 0 ? var.cert_manager.zone_ids : ["*"]
    content {
      actions   = ["route53:ChangeResourceRecordSets"]
      resources = statement.value == "*" ? ["*"] : ["arn:aws:route53:::hostedzone/${statement.value}"]
    }
  }
}

resource "aws_iam_role" "cert_manager" {
  count = var.enable_cert_manager ? 1 : 0
  name  = "irsa-cert-manager"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Action    = "sts:AssumeRoleWithWebIdentity",
      Principal = { Federated = var.oidc_provider_arn },
      Condition = {
        StringEquals = {
          "${local.oidc_hostpath}:aud" = "sts.amazonaws.com"
        },
        StringLike = {
          "${local.oidc_hostpath}:sub" = local.cert_manager_sa
        }
      }
    }]
  })
  tags = local.common_tags
}

resource "aws_iam_policy" "cert_manager" {
  count  = var.enable_cert_manager ? 1 : 0
  name   = "cert-manager-route53"
  policy = data.aws_iam_policy_document.cert_manager[0].json
}

resource "aws_iam_role_policy_attachment" "cert_manager_attach" {
  count      = var.enable_cert_manager ? 1 : 0
  role       = aws_iam_role.cert_manager[0].name
  policy_arn = aws_iam_policy.cert_manager[0].arn
}

data "aws_iam_policy_document" "cluster_autoscaler" {
  count = var.enable_cluster_autoscaler ? 1 : 0

  statement {
    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeTags",
      "ec2:DescribeLaunchTemplateVersions",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeImages",
      "ec2:DescribeSubnets",
      "ec2:DescribeInstanceTypeOfferings",
      "eks:DescribeNodegroup",
    ]
    resources = ["*"]
  }

  statement {
    actions = [
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
      "autoscaling:UpdateAutoScalingGroup",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "autoscaling:ResourceTag/kubernetes.io/cluster/${var.cluster_name}"
      values   = ["owned", "shared"]
    }
  }
}

resource "aws_iam_role" "cluster_autoscaler" {
  count = var.enable_cluster_autoscaler ? 1 : 0
  name  = "irsa-cluster-autoscaler"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Action    = "sts:AssumeRoleWithWebIdentity",
      Principal = { Federated = var.oidc_provider_arn },
      Condition = {
        StringEquals = {
          "${local.oidc_hostpath}:aud" = "sts.amazonaws.com"
        },
        StringLike = {
          "${local.oidc_hostpath}:sub" = ["system:serviceaccount:${coalesce(try(var.cluster_autoscaler.namespace, null), "kube-system")}:${coalesce(try(var.cluster_autoscaler.service_account, null), "cluster-autoscaler")}"]
        }
      }
    }]
  })
  tags = local.common_tags
}

resource "aws_iam_policy" "cluster_autoscaler" {
  count  = var.enable_cluster_autoscaler ? 1 : 0
  name   = "cluster-autoscaler"
  policy = data.aws_iam_policy_document.cluster_autoscaler[0].json
}

resource "aws_iam_role_policy_attachment" "cluster_autoscaler_attach" {
  count      = var.enable_cluster_autoscaler ? 1 : 0
  role       = aws_iam_role.cluster_autoscaler[0].name
  policy_arn = aws_iam_policy.cluster_autoscaler[0].arn
}

resource "aws_iam_role" "aws_lb_controller" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0
  name  = "irsa-aws-load-balancer-controller"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Action    = "sts:AssumeRoleWithWebIdentity",
      Principal = { Federated = var.oidc_provider_arn },
      Condition = {
        StringEquals = {
          "${local.oidc_hostpath}:aud" = "sts.amazonaws.com"
        },
        StringLike = {
          "${local.oidc_hostpath}:sub" = ["system:serviceaccount:${coalesce(try(var.aws_load_balancer_controller.namespace, null), "kube-system")}:${coalesce(try(var.aws_load_balancer_controller.service_account, null), "aws-load-balancer-controller")}"]
        }
      }
    }]
  })
  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "aws_lb_controller_attach" {
  count      = var.enable_aws_load_balancer_controller ? 1 : 0
  role       = aws_iam_role.aws_lb_controller[0].name
  policy_arn = "arn:aws:iam::aws:policy/AWSLoadBalancerControllerIAMPolicy" # available in many regions
}

locals {
  loki_sa_fqdns = var.enable_loki_s3 && var.loki_s3 != null ? [for sa in coalesce(var.loki_s3.service_accounts, ["loki"]) : "system:serviceaccount:${coalesce(var.loki_s3.namespace, "observability")}:${sa}"] : []
}

resource "aws_iam_role" "loki_s3" {
  count = var.enable_loki_s3 && var.loki_s3 != null ? 1 : 0
  name  = "irsa-loki"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Action    = "sts:AssumeRoleWithWebIdentity",
      Principal = { Federated = var.oidc_provider_arn },
      Condition = {
        StringEquals = {
          "${local.oidc_hostpath}:aud" = "sts.amazonaws.com"
        },
        StringLike = {
          "${local.oidc_hostpath}:sub" = local.loki_sa_fqdns
        }
      }
    }]
  })
  tags = local.common_tags
}

data "aws_iam_policy_document" "loki_s3" {
  count = var.enable_loki_s3 && var.loki_s3 != null ? 1 : 0

  statement {
    actions   = ["s3:ListBucket"]
    resources = [var.loki_s3.bucket_arn]
  }
  statement {
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:AbortMultipartUpload", "s3:ListBucketMultipartUploads"]
    resources = ["${var.loki_s3.bucket_arn}/*"]
  }
}

resource "aws_iam_policy" "loki_s3" {
  count  = var.enable_loki_s3 && var.loki_s3 != null ? 1 : 0
  name   = "loki-s3"
  policy = data.aws_iam_policy_document.loki_s3[0].json
}

resource "aws_iam_role_policy_attachment" "loki_s3_attach" {
  count      = var.enable_loki_s3 && var.loki_s3 != null ? 1 : 0
  role       = aws_iam_role.loki_s3[0].name
  policy_arn = aws_iam_policy.loki_s3[0].arn
}

locals {
  tempo_sa_fqdns = var.enable_tempo_s3 && var.tempo_s3 != null ? [for sa in coalesce(var.tempo_s3.service_accounts, ["tempo"]) : "system:serviceaccount:${coalesce(var.tempo_s3.namespace, "observability")}:${sa}"] : []
}

resource "aws_iam_role" "tempo_s3" {
  count = var.enable_tempo_s3 && var.tempo_s3 != null ? 1 : 0
  name  = "irsa-tempo"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Action    = "sts:AssumeRoleWithWebIdentity",
      Principal = { Federated = var.oidc_provider_arn },
      Condition = {
        StringEquals = {
          "${local.oidc_hostpath}:aud" = "sts.amazonaws.com"
        },
        StringLike = {
          "${local.oidc_hostpath}:sub" = local.tempo_sa_fqdns
        }
      }
    }]
  })
  tags = local.common_tags
}

data "aws_iam_policy_document" "tempo_s3" {
  count = var.enable_tempo_s3 && var.tempo_s3 != null ? 1 : 0

  statement {
    actions   = ["s3:ListBucket"]
    resources = [var.tempo_s3.bucket_arn]
  }
  statement {
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:AbortMultipartUpload", "s3:ListBucketMultipartUploads"]
    resources = ["${var.tempo_s3.bucket_arn}/*"]
  }
}

resource "aws_iam_policy" "tempo_s3" {
  count  = var.enable_tempo_s3 && var.tempo_s3 != null ? 1 : 0
  name   = "tempo-s3"
  policy = data.aws_iam_policy_document.tempo_s3[0].json
}

resource "aws_iam_role_policy_attachment" "tempo_s3_attach" {
  count      = var.enable_tempo_s3 && var.tempo_s3 != null ? 1 : 0
  role       = aws_iam_role.tempo_s3[0].name
  policy_arn = aws_iam_policy.tempo_s3[0].arn
}

# ── Preset: Otel Collector -> AWS X-Ray (PutTraceSegments) ────────────────────
resource "aws_iam_role" "otel_xray" {
  count = var.enable_otel_xray ? 1 : 0
  name  = "irsa-otel-xray"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Action    = "sts:AssumeRoleWithWebIdentity",
      Principal = { Federated = var.oidc_provider_arn },
      Condition = {
        StringEquals = {
          "${local.oidc_hostpath}:aud" = "sts.amazonaws.com"
        },
        StringLike = {
          "${local.oidc_hostpath}:sub" = ["system:serviceaccount:${coalesce(try(var.otel_xray.namespace, null), "observability")}:${coalesce(try(var.otel_xray.service_account, null), "otel-collector")}"]
        }
      }
    }]
  })
  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "otel_xray_awsmanaged" {
  count      = var.enable_otel_xray ? 1 : 0
  role       = aws_iam_role.otel_xray[0].name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}