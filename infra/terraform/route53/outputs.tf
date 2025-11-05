output "public_zone_id" {
  description = "ID of the public hosted zone (null if not created)"
  value       = local.public_zone_id
}

output "public_zone_arn" {
  description = "ARN of the public hosted zone (null if not created)"
  value       = local.public_zone_arn
}

output "public_zone_name_servers" {
  description = "Name servers for the public hosted zone (null if not created)"
  value       = local.public_zone_name_servers
}

output "private_zone_id" {
  description = "ID of the private hosted zone (null if not created)"
  value       = try(aws_route53_zone.private[0].zone_id, null)
}

output "private_zone_arn" {
  description = "ARN of the private hosted zone (null if not created)"
  value       = try(aws_route53_zone.private[0].arn, null)
}

output "zone_name" {
  description = "The domain name of the hosted zone"
  value       = local.public_zone_name
}

output "query_log_group_name" {
  description = "CloudWatch Log Group name used for query logging (null if not enabled)"
  value       = try(aws_cloudwatch_log_group.query_logs[0].name, null)
}

output "query_log_group_arn" {
  description = "CloudWatch Log Group ARN used for query logging (null if not enabled)"
  value       = try(aws_cloudwatch_log_group.query_logs[0].arn, null)
}

output "dnssec_kms_key_arn" {
  description = "KMS CMK ARN used for DNSSEC KSK (null if DNSSEC not enabled)"
  value       = try(coalesce(var.dnssec_kms_key_arn, aws_kms_key.dnssec[0].arn), null)
}

output "dnssec_key_signing_key_id" {
  description = "ID of the DNSSEC key signing key (null if DNSSEC not enabled)"
  value       = try(aws_route53_key_signing_key.this[0].id, null)
}