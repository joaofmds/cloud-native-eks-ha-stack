data "aws_caller_identity" "this" {}
data "aws_region" "this" {}

locals {
  common_tags = merge({
    ManagedBy   = "Terraform",
    Project     = var.project,
    Environment = var.environment,
    Owner       = var.owner,
  }, var.tags)

  zone_tags = merge(local.common_tags, { Name = var.zone_name })
  using_existing_public_zone = !var.create_public_zone && var.existing_public_zone_id != null
}

data "aws_route53_zone" "existing_public" {
  count        = local.using_existing_public_zone ? 1 : 0
  zone_id      = var.existing_public_zone_id
  private_zone = false
}

locals {
  public_zone_id = var.create_public_zone ? try(aws_route53_zone.public[0].zone_id, null) : (local.using_existing_public_zone ? data.aws_route53_zone.existing_public[0].zone_id : null)
  public_zone_arn = var.create_public_zone ? try(aws_route53_zone.public[0].arn, null) : (local.using_existing_public_zone ? data.aws_route53_zone.existing_public[0].arn : null)
  public_zone_name_servers = var.create_public_zone ? try(aws_route53_zone.public[0].name_servers, null) : (local.using_existing_public_zone ? data.aws_route53_zone.existing_public[0].name_servers : null)
  public_zone_name = var.create_public_zone ? try(aws_route53_zone.public[0].name, var.zone_name) : (local.using_existing_public_zone ? data.aws_route53_zone.existing_public[0].name : var.zone_name)
  private_zone_id = var.create_private_zone ? try(aws_route53_zone.private[0].zone_id, null) : null
}

resource "aws_route53_zone" "public" {
  count   = var.create_public_zone ? 1 : 0
  name    = var.zone_name
  comment = var.comment
  tags    = local.zone_tags
}

resource "aws_route53_zone" "private" {
  count   = var.create_private_zone ? 1 : 0
  name    = var.zone_name
  comment = var.comment
  vpc {
    vpc_id = var.private_zone_vpc_associations != [] ? var.private_zone_vpc_associations[0].vpc_id : null
  }
  tags = merge(local.zone_tags, { Scope = "private" })
}

resource "aws_route53_vpc_association_authorization" "private" {
  for_each = var.create_private_zone ? {
    for idx, v in var.private_zone_vpc_associations : idx => v
  } : {}
  zone_id    = aws_route53_zone.private[0].zone_id
  vpc_id     = each.value.vpc_id
  vpc_region = try(each.value.vpc_region, data.aws_region.this.id)
  lifecycle { create_before_destroy = true }
}

resource "aws_route53_zone_association" "private" {
  for_each = var.create_private_zone ? {
    for idx, v in var.private_zone_vpc_associations : idx => v
  } : {}
  zone_id    = aws_route53_zone.private[0].zone_id
  vpc_id     = each.value.vpc_id
  vpc_region = try(each.value.vpc_region, data.aws_region.this.id)
  depends_on = [aws_route53_vpc_association_authorization.private]
}

resource "aws_kms_key" "dnssec" {
  count                   = var.enable_dnssec && var.create_dnssec_kms_key && var.dnssec_kms_key_arn == null && var.create_public_zone ? 1 : 0
  description             = "DNSSEC KSK for ${var.zone_name}"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "Enable IAM User Permissions",
        Effect    = "Allow",
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.this.account_id}:root" },
        Action    = "kms:*",
        Resource  = "*"
      },
      {
        Sid       = "Allow Route53 DNSSEC",
        Effect    = "Allow",
        Principal = { Service = "dnssec-route53.amazonaws.com" },
        Action = [
          "kms:DescribeKey",
          "kms:GetPublicKey",
          "kms:Sign",
          "kms:CreateGrant",
          "kms:RetireGrant",
          "kms:RevokeGrant",
          "kms:ListGrants"
        ],
        Resource = "*",
        Condition = {
          StringEquals = {
            "kms:CallerAccount" : data.aws_caller_identity.this.account_id,
            "kms:ViaService" : "dnssec-route53.${data.aws_region.this.id}.amazonaws.com"
          }
        }
      }
    ]
  })
  tags = local.common_tags
}

resource "aws_route53_key_signing_key" "this" {
  count                      = var.enable_dnssec && var.create_public_zone ? 1 : 0
  hosted_zone_id             = local.public_zone_id
  key_management_service_arn = var.dnssec_kms_key_arn != null ? var.dnssec_kms_key_arn : aws_kms_key.dnssec[0].arn
  name                       = replace(var.zone_name, ".", "-")
}

resource "aws_route53_hosted_zone_dnssec" "this" {
  count          = var.enable_dnssec && var.create_public_zone ? 1 : 0
  hosted_zone_id = local.public_zone_id
  depends_on     = [aws_route53_key_signing_key.this]
}

resource "aws_cloudwatch_log_group" "query_logs" {
  count             = var.enable_query_logging && var.create_public_zone ? 1 : 0
  name              = coalesce(var.query_log_group_name, "/route53/${var.zone_name}")
  retention_in_days = 30
  kms_key_id        = var.query_logs_kms_key_arn
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_resource_policy" "route53" {
  count       = var.enable_query_logging && var.create_public_zone ? 1 : 0
  policy_name = "Route53QueryLogs-${replace(var.zone_name, ".", "-")}"
  policy_document = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Sid       = "AllowRoute53ToWrite",
      Effect    = "Allow",
      Principal = { Service = "route53.amazonaws.com" },
      Action    = ["logs:CreateLogStream", "logs:PutLogEvents"],
      Resource  = "${aws_cloudwatch_log_group.query_logs[0].arn}:*"
    }]
  })
}

resource "aws_route53_query_log" "this" {
  count                    = var.enable_query_logging && var.create_public_zone ? 1 : 0
  cloudwatch_log_group_arn = aws_cloudwatch_log_group.query_logs[0].arn
  zone_id                  = local.public_zone_id
  depends_on               = [aws_cloudwatch_log_resource_policy.route53]
}

resource "aws_route53_record" "apex_a" {
  count   = var.apex_alias != null && local.public_zone_id != null ? 1 : 0
  zone_id = local.public_zone_id
  name    = var.zone_name
  type    = "A"
  alias {
    name                   = var.apex_alias.dns_name
    zone_id                = var.apex_alias.zone_id
    evaluate_target_health = try(var.apex_alias.evaluate_target_health, false)
  }
}

resource "aws_route53_record" "apex_aaaa" {
  count   = var.apex_alias != null && local.public_zone_id != null && try(var.apex_alias.create_aaaa, true) ? 1 : 0
  zone_id = local.public_zone_id
  name    = var.zone_name
  type    = "AAAA"
  alias {
    name                   = var.apex_alias.dns_name
    zone_id                = var.apex_alias.zone_id
    evaluate_target_health = try(var.apex_alias.evaluate_target_health, false)
  }
}

locals {
  additional_aliases = [for r in var.additional_alias_records : {
    name     = contains(r.name, ".") ? r.name : "${r.name}.${var.zone_name}"
    type     = coalesce(r.type, "A")
    dns_name = r.dns_name
    zone_id  = r.zone_id
    evaluate = try(r.evaluate_target_health, false)
    aaaa     = try(r.create_aaaa, true)
  }]
}

resource "aws_route53_record" "alias_records_a" {
  for_each = local.public_zone_id != null ? { for i, r in local.additional_aliases : i => r if r.type == "A" } : {}
  zone_id  = local.public_zone_id
  name     = each.value.name
  type     = "A"
  alias {
    name                   = each.value.dns_name
    zone_id                = each.value.zone_id
    evaluate_target_health = each.value.evaluate
  }
}

resource "aws_route53_record" "alias_records_aaaa" {
  for_each = local.public_zone_id != null ? { for i, r in local.additional_aliases : i => r if r.aaaa } : {}
  zone_id  = local.public_zone_id
  name     = each.value.name
  type     = "AAAA"
  alias {
    name                   = each.value.dns_name
    zone_id                = each.value.zone_id
    evaluate_target_health = each.value.evaluate
  }
}

locals {
  simple_records = [for r in var.simple_records : {
    name    = contains(r.name, ".") ? r.name : "${r.name}.${var.zone_name}"
    type    = r.type
    ttl     = r.ttl
    records = r.records
  }]

  any_zone_available = var.create_public_zone || local.using_existing_public_zone || var.create_private_zone
}

resource "aws_route53_record" "simple" {
  for_each = local.any_zone_available ? { for i, r in local.simple_records : i => r } : {}
  zone_id  = local.public_zone_id != null ? local.public_zone_id : local.private_zone_id
  name     = each.value.name
  type     = each.value.type
  ttl      = each.value.ttl
  records  = each.value.records
}

resource "aws_route53_health_check" "failover" {
  for_each          = { for i, r in var.failover_records : i => r if try(r.health_check != null, false) }
  fqdn              = each.value.health_check.fqdn
  port              = each.value.health_check.port
  type              = each.value.health_check.type
  resource_path     = try(each.value.health_check.resource_path, "/")
  request_interval  = try(each.value.health_check.request_interval, 30)
  failure_threshold = try(each.value.health_check.failure_threshold, 3)
  tags              = local.common_tags
}

resource "aws_route53_record" "failover" {
  for_each       = local.any_zone_available ? { for i, r in var.failover_records : i => r } : {}
  zone_id        = local.public_zone_id != null ? local.public_zone_id : local.private_zone_id
  name           = contains(each.value.name, ".") ? each.value.name : "${each.value.name}.${var.zone_name}"
  type           = each.value.type
  set_identifier = each.value.set_identifier
  failover_routing_policy {
    type = upper(each.value.failover) # PRIMARY or SECONDARY
  }
  health_check_id = try(aws_route53_health_check.failover[each.key].id, null)
  ttl             = each.value.ttl
  records         = each.value.records
}

resource "aws_route53_record" "acm" {
  for_each = local.any_zone_available ? var.acm_validation_records : {}
  zone_id  = local.public_zone_id != null ? local.public_zone_id : local.private_zone_id
  name     = each.key
  type     = "CNAME"
  ttl      = 300
  records  = [each.value]
}

resource "aws_route53_record" "delegations" {
  for_each = local.public_zone_id != null ? var.delegate_subdomains : {}
  zone_id  = local.public_zone_id
  name     = each.key
  type     = "NS"
  ttl      = 172800
  records  = each.value
}
