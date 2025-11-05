data "aws_caller_identity" "this" {}
data "aws_region" "this" {}

locals {
  common_tags = merge({
    ManagedBy   = "Terraform",
    Project     = var.project,
    Environment = var.environment,
    Owner       = var.owner,
  }, var.tags)

  repos = {
    for k, v in var.repositories : k => merge(v, {
      _name         = coalesce(try(v.name, null), k)
      _immutability = upper(coalesce(try(v.image_tag_mutability, null), (try(v.immutable_tags, true) ? "IMMUTABLE" : "MUTABLE")))
    })
  }
}

resource "aws_ecr_repository" "this" {
  for_each = local.repos

  name                 = each.value._name
  image_tag_mutability = each.value._immutability

  image_scanning_configuration { scan_on_push = try(each.value.scan_on_push, true) }

  encryption_configuration {
    encryption_type = try(each.value.kms_key_arn, null) == null ? "AES256" : "KMS"
    kms_key         = try(each.value.kms_key_arn, null)
  }

  force_delete = try(each.value.force_delete, false)

  tags = merge(local.common_tags, { Name = each.value._name })
}

resource "aws_ecr_lifecycle_policy" "this" {
  for_each = {
    for k, v in local.repos : k => v if try(v.lifecycle_policy_json, null) != null || try(v.lifecycle_keep_last, null) != null || try(v.lifecycle_expire_untagged_days, null) != null
  }

  repository = aws_ecr_repository.this[each.key].name
  policy = coalesce(
    try(each.value.lifecycle_policy_json, null),
    jsonencode({
      rules = compact([
        try(each.value.lifecycle_keep_last, null) != null ? {
          rulePriority = 1,
          description  = "keep last N images",
          selection    = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = each.value.lifecycle_keep_last },
          action       = { type = "expire" }
        } : null,
        try(each.value.lifecycle_expire_untagged_days, null) != null ? {
          rulePriority = 2,
          description  = "expire untagged older than N days",
          selection    = { tagStatus = "untagged", countType = "sinceImagePushed", countUnit = "days", countNumber = each.value.lifecycle_expire_untagged_days },
          action       = { type = "expire" }
        } : null
      ])
    })
  )
}

locals {
  repo_policies = {
    for k, v in local.repos : k => {
      allow_push_arns = try(v.push_principal_arns, [])
      allow_pull_arns = try(v.pull_principal_arns, [])
    }
  }
}

resource "aws_ecr_repository_policy" "this" {
  for_each = { for k, v in local.repo_policies : k => v if length(v.allow_push_arns) + length(v.allow_pull_arns) > 0 }

  repository = aws_ecr_repository.this[each.key].name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = compact(concat(
      length(each.value.allow_push_arns) > 0 ? [{
        Sid       = "AllowPush",
        Effect    = "Allow",
        Principal = { AWS = each.value.allow_push_arns },
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer"
        ]
      }] : [],
      length(each.value.allow_pull_arns) > 0 ? [{
        Sid       = "AllowPull",
        Effect    = "Allow",
        Principal = { AWS = each.value.allow_pull_arns },
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer"
        ]
      }] : []
    ))
  })
}

resource "aws_ecr_registry_scanning_configuration" "this" {
  scan_type = var.enable_registry_enhanced_scanning ? "ENHANCED" : "BASIC"

  dynamic "rule" {
    for_each = var.registry_scan_rules != null ? [1] : []
    content {
      scan_frequency = "SCAN_ON_PUSH"
      repository_filter {
        filter      = "*"
        filter_type = "WILDCARD"
      }
    }
  }
}

resource "aws_ecr_registry_policy" "this" {
  count  = var.registry_policy_json != null ? 1 : 0
  policy = var.registry_policy_json
}

resource "aws_ecr_replication_configuration" "this" {
  count = length(var.replication_rules) > 0 ? 1 : 0

  replication_configuration {
    dynamic "rule" {
      for_each = var.replication_rules
      content {
        dynamic "destination" {
          for_each = rule.value.destinations
          content {
            region      = destination.value.region
            registry_id = try(destination.value.registry_id, null)
          }
        }
        dynamic "repository_filter" {
          for_each = rule.value.repository_filter != null ? [1] : []
          content {
            filter      = rule.value.repository_filter.prefix
            filter_type = "PREFIX"
          }
        }
      }
    }
  }
}


