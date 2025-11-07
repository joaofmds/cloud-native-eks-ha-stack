data "aws_caller_identity" "this" {}

data "aws_region" "this" {}

locals {
  common_tags = merge({
    ManagedBy   = "Terraform",
    Project     = var.project,
    Environment = var.environment,
    Owner       = var.owner,
  }, var.tags)

  default_prefixes = merge({
    chunks = "chunks/",
    index  = "index/",
    ruler  = "ruler/",
    admin  = "admin/",
  }, var.prefixes)

  bucket_name = coalesce(
    var.bucket_name,
    lower(replace("${var.name_prefix}-${data.aws_region.this.id}-${data.aws_caller_identity.this.account_id}", "_", "-"))
  )
}

resource "aws_s3_bucket" "this" {
  bucket        = local.bucket_name
  force_destroy = var.force_destroy
  tags          = merge(local.common_tags, { Name = local.bucket_name, Purpose = "loki" })
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "this" {
  bucket     = aws_s3_bucket.this.id
  acl        = "private"
  depends_on = [aws_s3_bucket_ownership_controls.this]
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn == null ? "AES256" : "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = var.kms_key_arn != null
  }
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration { status = var.versioning ? "Enabled" : "Suspended" }
}

resource "aws_s3_bucket_logging" "this" {
  count         = try(var.access_logging.enabled, false) && try(var.access_logging.target_bucket, null) != null ? 1 : 0
  bucket        = aws_s3_bucket.this.id
  target_bucket = var.access_logging.target_bucket
  target_prefix = var.access_logging.target_prefix
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  dynamic "rule" {
    for_each = {
      for k, v in local.default_prefixes : k => {
        prefix = v
        cfg    = lookup(var.lifecycle_rules, k, null)
      }
    }

    content {
      id     = "loki-${rule.key}"
      status = "Enabled"

      filter { prefix = rule.value.prefix }

      dynamic "transition" {
        for_each = rule.value.cfg.transition_to_ia_after_days != null ? [1] : []
        content {
          days          = rule.value.cfg.transition_to_ia_after_days
          storage_class = "STANDARD_IA"
        }
      }

      expiration { days = rule.value.cfg.expire_after_days }
    }
  }
}

locals {
  writers = toset(var.allowed_writer_role_arns)
  readers = toset(var.allowed_reader_role_arns)

  statements_base = [
    for statement in [
      var.deny_insecure_transport ? {
        Sid       = "DenyInsecureTransport",
        Effect    = "Deny",
        Principal = "*",
        Action    = "s3:*",
        Resource  = [aws_s3_bucket.this.arn, "${aws_s3_bucket.this.arn}/*"],
        Condition = { Bool = { "aws:SecureTransport" = false } }
      } : null,

      var.require_sse_kms && var.kms_key_arn != null ? {
        Sid       = "DenyUnEncryptedUploads",
        Effect    = "Deny",
        Principal = "*",
        Action    = ["s3:PutObject"],
        Resource  = "${aws_s3_bucket.this.arn}/*",
        Condition = {
          StringNotEquals = { "s3:x-amz-server-side-encryption" = "aws:kms" },
        }
      } : null,

      var.require_sse_kms && var.kms_key_arn != null ? {
        Sid       = "DenyWrongKmsKey",
        Effect    = "Deny",
        Principal = "*",
        Action    = ["s3:PutObject"],
        Resource  = "${aws_s3_bucket.this.arn}/*",
        Condition = {
          StringNotEquals = { "s3:x-amz-server-side-encryption-aws-kms-key-id" = var.kms_key_arn }
        }
      } : null
    ] : statement if statement != null
  ]

  statements_access = concat(
    length(local.writers) > 0 ? [{
      Sid       = "AllowListForWriters",
      Effect    = "Allow",
      Principal = { AWS = tolist(local.writers) },
      Action    = ["s3:ListBucket"],
      Resource  = aws_s3_bucket.this.arn,
      Condition = {
        StringLike = {
          "s3:prefix" = [local.default_prefixes.chunks, local.default_prefixes.index, local.default_prefixes.ruler, local.default_prefixes.admin]
        }
      }
    }] : [],

    length(local.readers) > 0 ? [{
      Sid       = "AllowListForReaders",
      Effect    = "Allow",
      Principal = { AWS = tolist(local.readers) },
      Action    = ["s3:ListBucket"],
      Resource  = aws_s3_bucket.this.arn,
      Condition = {
        StringLike = {
          "s3:prefix" = [local.default_prefixes.chunks, local.default_prefixes.index, local.default_prefixes.ruler, local.default_prefixes.admin]
        }
      }
    }] : [],

    length(local.writers) > 0 ? [{
      Sid       = "AllowWriteReadDeleteForWriters",
      Effect    = "Allow",
      Principal = { AWS = tolist(local.writers) },
      Action    = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:AbortMultipartUpload", "s3:ListBucketMultipartUploads"],
      Resource = [
        "${aws_s3_bucket.this.arn}/${local.default_prefixes.chunks}*",
        "${aws_s3_bucket.this.arn}/${local.default_prefixes.index}*",
        "${aws_s3_bucket.this.arn}/${local.default_prefixes.ruler}*",
        "${aws_s3_bucket.this.arn}/${local.default_prefixes.admin}*",
      ]
    }] : [],

    length(local.readers) > 0 ? [{
      Sid       = "AllowReadForReaders",
      Effect    = "Allow",
      Principal = { AWS = tolist(local.readers) },
      Action    = ["s3:GetObject"],
      Resource = [
        "${aws_s3_bucket.this.arn}/${local.default_prefixes.chunks}*",
        "${aws_s3_bucket.this.arn}/${local.default_prefixes.index}*",
        "${aws_s3_bucket.this.arn}/${local.default_prefixes.ruler}*",
        "${aws_s3_bucket.this.arn}/${local.default_prefixes.admin}*",
      ]
    }] : []
  )
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = concat(local.statements_base, local.statements_access)
  })
}