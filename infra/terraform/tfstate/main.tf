locals {
  common_tags = merge(var.tags, {
    Environment = var.environment
    Project     = var.project_name
    Owner       = var.owner
    Application = var.application
  })
}

resource "aws_s3_bucket" "log_bucket" {
  bucket = "bry-project-tfstate-logs-${var.environment}"

  tags = merge(local.common_tags, {
    Name = "bry-project-tfstate-logs-${var.environment}"
  })
}

resource "aws_s3_bucket" "this" {
  bucket = "bry-project-tfstate-${var.environment}"

  lifecycle {
    prevent_destroy = false
  }

  tags = merge(local.common_tags, {
    Name = "bry-project-tfstate-${var.environment}"
  })
}

resource "aws_s3_bucket_logging" "this" {
  bucket        = aws_s3_bucket.this.id
  target_bucket = aws_s3_bucket.log_bucket.id
  target_prefix = "logs/${var.environment}/${var.project_name}/"

  depends_on = [aws_s3_bucket.log_bucket]
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "this" {
  name         = "terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = merge(local.common_tags, {
    Name = "terraform-locks"
  })
}
