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
    for combo in flatten([
      for key, cfg in var.generic_irsa_roles : [
        for idx, policy in try(cfg.managed_policy_arns, []) : {
          key        = "${key}-${idx}"
          role_key   = key
          policy_arn = policy
        }
      ]
    ]) : combo.key => combo
  }

  role       = aws_iam_role.generic[each.value.role_key].name
  policy_arn = each.value.policy_arn
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
      sid       = statement.value == "*" ? "ChangeRecordsAll" : "ChangeRecords${replace(replace(statement.value, "/", ""), "-", "")}"
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

data "aws_iam_policy_document" "aws_lb_controller" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  statement {
    sid = "ALBIngressController1"
    actions = [
      "acm:ListCertificates",
      "acm:DescribeCertificate",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:CreateSecurityGroup",
      "ec2:CreateTags",
      "ec2:DeleteTags",
      "ec2:DeleteSecurityGroup",
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeAddresses",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceStatus",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeTags",
      "ec2:DescribeVpcs",
      "ec2:ModifyInstanceAttribute",
      "ec2:ModifyNetworkInterfaceAttribute",
      "ec2:RevokeSecurityGroupIngress"
    ]
    resources = ["*"]
  }

  statement {
    sid = "ALBIngressController2"
    actions = [
      "elasticloadbalancing:*"
    ]
    resources = ["*"]
  }

  statement {
    sid = "ALBIngressController3"
    actions = [
      "iam:CreateServiceLinkedRole",
      "iam:GetServerCertificate",
      "iam:ListServerCertificates"
    ]
    resources = ["*"]
  }

  statement {
    sid = "ALBIngressController4"
    actions = [
      "cognito-idp:DescribeUserPoolClient"
    ]
    resources = ["*"]
  }

  statement {
    sid = "ALBIngressController5"
    actions = [
      "waf-regional:GetWebACL",
      "waf-regional:GetWebACLForResource",
      "waf-regional:AssociateWebACL",
      "waf-regional:DisassociateWebACL",
      "waf:GetWebACL",
      "wafv2:GetWebACL",
      "wafv2:GetWebACLForResource",
      "wafv2:AssociateWebACL",
      "wafv2:DisassociateWebACL"
    ]
    resources = ["*"]
  }

  statement {
    sid = "ALBIngressController6"
    actions = [
      "tag:GetResources",
      "tag:TagResources"
    ]
    resources = ["*"]
  }

  statement {
    sid = "ALBIngressController7"
    actions = [
      "waf:GetWebACL"
    ]
    resources = ["*"]
  }

  statement {
    sid = "ALBIngressController8"
    actions = [
      "shield:DescribeProtection",
      "shield:GetSubscriptionState",
      "shield:DescribeSubscription",
      "shield:CreateProtection",
      "shield:DeleteProtection"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "aws_lb_controller" {
  count  = var.enable_aws_load_balancer_controller ? 1 : 0
  name   = "AWSLoadBalancerControllerIAMPolicy"
  policy = data.aws_iam_policy_document.aws_lb_controller[0].json
  tags   = local.common_tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_role_policy_attachment" "aws_lb_controller_attach" {
  count      = var.enable_aws_load_balancer_controller ? 1 : 0
  role       = aws_iam_role.aws_lb_controller[0].name
  policy_arn = aws_iam_policy.aws_lb_controller[0].arn
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
  ebs_csi_sa_fqdns = var.enable_ebs_csi_driver && var.ebs_csi_driver != null ? [
    "system:serviceaccount:${coalesce(var.ebs_csi_driver.namespace, "kube-system")}:${coalesce(var.ebs_csi_driver.service_account, "ebs-csi-controller-sa")}"
  ] : []
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
resource "aws_iam_role" "ebs_csi_driver" {
  count = var.enable_ebs_csi_driver ? 1 : 0
  name  = "irsa-ebs-csi-driver"
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
          "${local.oidc_hostpath}:sub" = local.ebs_csi_sa_fqdns
        }
      }
    }]
  })
  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  count      = var.enable_ebs_csi_driver ? 1 : 0
  role       = aws_iam_role.ebs_csi_driver[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

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

# Após o bloco otel_xray, adicionar:

resource "aws_iam_role" "grafana" {
  count = var.enable_grafana_s3 ? 1 : 0
  name  = "irsa-grafana"
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
          "${local.oidc_hostpath}:sub" = ["system:serviceaccount:${coalesce(try(var.grafana.namespace, null), "monitoring")}:${coalesce(try(var.grafana.service_account, null), "kube-prometheus-stack-grafana")}"]
        }
      }
    }]
  })
  tags = local.common_tags
}

# Policy para Grafana ler de S3 (se necessário para imagens/exports)
data "aws_iam_policy_document" "grafana" {
  count = var.enable_grafana_s3 ? 1 : 0
  statement {
    actions   = ["s3:ListBucket", "s3:GetObject", "s3:PutObject"]
    resources = [var.grafana_s3.bucket_arn, "${var.grafana_s3.bucket_arn}/*"]
  }
}

resource "aws_iam_policy" "grafana" {
  count  = var.enable_grafana_s3 ? 1 : 0
  name   = "grafana-s3"
  policy = data.aws_iam_policy_document.grafana[0].json
}

resource "aws_iam_role_policy_attachment" "grafana" {
  count      = var.enable_grafana_s3 ? 1 : 0
  role       = aws_iam_role.grafana[0].name
  policy_arn = aws_iam_policy.grafana[0].arn
}