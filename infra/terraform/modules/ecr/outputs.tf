output "repositories" {
  description = "Map of repository keys to their details (name, arn, url)"
  value = {
    for k, r in aws_ecr_repository.this : k => {
      name = r.name
      arn  = r.arn
      url  = r.repository_url
    }
  }
}

output "repository_names" {
  description = "Map of repository keys to their names"
  value       = { for k, r in aws_ecr_repository.this : k => r.name }
}

output "repository_arns" {
  description = "Map of repository keys to their ARNs"
  value       = { for k, r in aws_ecr_repository.this : k => r.arn }
}

output "repository_urls" {
  description = "Map of repository keys to their URLs"
  value       = { for k, r in aws_ecr_repository.this : k => r.repository_url }
}

output "registry_id" {
  description = "ECR registry ID (AWS account ID)"
  value       = length(aws_ecr_repository.this) > 0 ? one(aws_ecr_repository.this).registry_id : data.aws_caller_identity.this.account_id
}

output "region" {
  description = "AWS region where the ECR repositories are located"
  value       = data.aws_region.this.name
}

output "lifecycle_policies" {
  description = "Map of repository keys that have lifecycle policies configured"
  value       = { for k, lp in aws_ecr_lifecycle_policy.this : k => true }
}

output "repository_policies" {
  description = "Map of repository keys that have repository policies configured"
  value       = { for k, rp in aws_ecr_repository_policy.this : k => true }
}