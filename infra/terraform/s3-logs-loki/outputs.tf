output "bucket_name" {
  description = "Name of the S3 bucket created for storing logs and Loki data"
  value       = aws_s3_bucket.this.bucket
}

output "bucket_arn" {
  description = "ARN of the S3 bucket created for storing logs and Loki data"
  value       = aws_s3_bucket.this.arn
}

output "bucket_id" {
  description = "ID of the S3 bucket created for storing logs and Loki data"
  value       = aws_s3_bucket.this.id
}

output "bucket_domain_name" {
  description = "Domain name of the S3 bucket created for storing logs and Loki data"
  value       = aws_s3_bucket.this.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "Regional domain name of the S3 bucket created for storing logs and Loki data"
  value       = aws_s3_bucket.this.bucket_regional_domain_name
}

output "prefixes" {
  description = "Default prefixes configured for organizing logs and data within the S3 bucket"
  value       = local.default_prefixes
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for S3 bucket encryption (if KMS encryption is enabled)"
  value       = var.kms_key_arn
}