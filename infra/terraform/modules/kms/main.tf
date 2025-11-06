data "aws_caller_identity" "this" {}
data "aws_region" "this" {}

locals {
  common_tags = merge({
    ManagedBy   = "Terraform",
    Project     = var.project,
    Environment = var.environment,
    Owner       = var.owner,
  }, var.tags)

  account_id = data.aws_caller_identity.this.account_id

  base_admin_actions = [
    "kms:Create*", "kms:Describe*", "kms:Enable*", "kms:List*", "kms:Put*",
    "kms:Update*", "kms:Revoke*", "kms:Disable*", "kms:Get*", "kms:Delete*",
    "kms:ScheduleKeyDeletion", "kms:CancelKeyDeletion",
  ]

  base_use_actions = [
    "kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"
  ]
}

resource "aws_kms_key" "this" {
  for_each                = var.keys
  description             = coalesce(each.value.description, "${var.name_prefix}/${each.key}")
  deletion_window_in_days = each.value.deletion_window_days
  multi_region            = each.value.multi_region
  enable_key_rotation     = each.value.enable_rotation

  tags = merge(local.common_tags, { Name = "${var.name_prefix}-${each.key}" })

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      for statement in [
        {
          Sid       = "AllowRootAccountAdmin",
          Effect    = "Allow",
          Principal = { AWS = "arn:aws:iam::${local.account_id}:root" },
          Action    = local.base_admin_actions,
          Resource  = "*"
        },

        length(each.value.admins_iam_arns) > 0 ? {
          Sid       = "AllowAdditionalAdmins",
          Effect    = "Allow",
          Principal = { AWS = each.value.admins_iam_arns },
          Action    = local.base_admin_actions,
          Resource  = "*"
        } : null,

        length(each.value.users_iam_arns) > 0 ? {
          Sid       = "AllowKeyUsageForUsers",
          Effect    = "Allow",
          Principal = { AWS = each.value.users_iam_arns },
          Action    = local.base_use_actions,
          Resource  = "*"
        } : null,

        length(each.value.cloudwatch_logs_arns) > 0 ? {
          Sid       = "AllowCloudWatchLogsService",
          Effect    = "Allow",
          Principal = { Service = "logs.${data.aws_region.this.id}.amazonaws.com" },
          Action    = local.base_use_actions,
          Resource  = "*",
          Condition = {
            StringLike = {
              "kms:EncryptionContext:aws:logs:arn" : each.value.cloudwatch_logs_arns
            }
          }
        } : null,

        length(each.value.cloudtrail_trail_arns) > 0 ? {
          Sid       = "AllowCloudTrailService",
          Effect    = "Allow",
          Principal = { Service = "cloudtrail.amazonaws.com" },
          Action    = local.base_use_actions,
          Resource  = "*",
          Condition = {
            StringEquals = {
              "kms:EncryptionContext:aws:cloudtrail:arn" : each.value.cloudtrail_trail_arns
            }
          }
        } : null,

        length(each.value.allow_cross_account_arns) > 0 ? {
          Sid       = "AllowCrossAccountUse",
          Effect    = "Allow",
          Principal = { AWS = each.value.allow_cross_account_arns },
          Action    = local.base_use_actions,
          Resource  = "*"
        } : null
      ] : statement if statement != null
    ]
  })
}

resource "aws_kms_alias" "this" {
  for_each      = var.keys
  name          = "alias/${var.name_prefix}/${each.value.alias}"
  target_key_id = aws_kms_key.this[each.key].key_id
}