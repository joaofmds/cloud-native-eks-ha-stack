data "aws_caller_identity" "this" {}

data "aws_region" "this" {}

locals {
  common_tags = merge({
    ManagedBy   = "Terraform",
    Project     = var.project,
    Environment = var.environment,
    Owner       = var.owner,
  }, var.tags)

  bucket_name = coalesce(
    var.bucket_name,
    lower(replace("${var.name_prefix}-tempo-${data.aws_region.this.name}-${data.aws_caller_identity.this.account_id}", "_", "-"))
  )
}

resource "aws_s3_bucket" "this" {
  bucket        = local.bucket_name
  force_destroy = var.force_destroy
  tags          = merge(local.common_tags, { Name = local.bucket_name, Purpose = "tempo" })
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
  bucket = aws_s3_bucket.this.id
  acl    = "private"
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
  count = try(var.access_logging.enabled, false) && try(var.access_logging.target_bucket, null) != null ? 1 : 0

  bucket        = aws_s3_bucket.this.id
  target_bucket = var.access_logging.target_bucket
  target_prefix = var.access_logging.target_prefix
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count = var.retention_days != null ? 1 : 0

  bucket = aws_s3_bucket.this.id

  rule {
    id     = "tempo-retention"
    status = "Enabled"

    expiration {
      days = var.retention_days
    }
  }
}

locals {
  allow_statements = length(var.allowed_role_arns) > 0 ? [{
    Sid       = "AllowTempoAccess",
    Effect    = "Allow",
    Principal = { AWS = var.allowed_role_arns },
    Action    = [
      "s3:AbortMultipartUpload",
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
      "s3:PutObject"
    ],
    Resource = [aws_s3_bucket.this.arn, "${aws_s3_bucket.this.arn}/*"]
  }] : []

  deny_statements = compact([
    var.deny_insecure_transport ? {
      Sid      = "DenyInsecureTransport",
      Effect   = "Deny",
      Principal= "*",
      Action   = "s3:*",
      Resource = [aws_s3_bucket.this.arn, "${aws_s3_bucket.this.arn}/*"],
      Condition= { Bool = { "aws:SecureTransport" = false } }
    } : null,
    var.require_sse_kms && var.kms_key_arn != null ? {
      Sid      = "DenyUnEncryptedUploads",
      Effect   = "Deny",
      Principal= "*",
      Action   = ["s3:PutObject"],
      Resource = "${aws_s3_bucket.this.arn}/*",
      Condition= {
        StringNotEquals = { "s3:x-amz-server-side-encryption" = "aws:kms" }
      }
    } : null,
    var.require_sse_kms && var.kms_key_arn != null ? {
      Sid      = "DenyWrongKmsKey",
      Effect   = "Deny",
      Principal= "*",
      Action   = ["s3:PutObject"],
      Resource = "${aws_s3_bucket.this.arn}/*",
      Condition= {
        StringNotEquals = { "s3:x-amz-server-side-encryption-aws-kms-key-id" = var.kms_key_arn }
      }
    } : null
  ])
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = concat(local.allow_statements, local.deny_statements)
  })
}
