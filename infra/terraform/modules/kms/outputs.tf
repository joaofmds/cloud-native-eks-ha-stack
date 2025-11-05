output "key_arns" {
  description = "Map of logical key name to KMS Key ARN"
  value       = { for k, v in aws_kms_key.this : k => v.arn }
}

output "alias_arns" {
  description = "Map of logical key name to KMS Alias ARN"
  value       = { for k, v in aws_kms_alias.this : k => v.arn }
}

output "alias_names" {
  description = "Map of logical key name to KMS Alias name (alias/...)"
  value       = { for k, v in aws_kms_alias.this : k => v.name }
}