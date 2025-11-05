output "generic_roles" {
  description = "Map key => role ARN for generic IRSA roles"
  value       = { for k, r in aws_iam_role.generic : k => r.arn }
}

output "external_dns_role_arn" {
  description = "IAM role ARN for External DNS service account (null if disabled)"
  value       = try(aws_iam_role.external_dns[0].arn, null)
}

output "cert_manager_role_arn" {
  description = "IAM role ARN for Cert Manager service account (null if disabled)"
  value       = try(aws_iam_role.cert_manager[0].arn, null)
}

output "cluster_autoscaler_role_arn" {
  description = "IAM role ARN for Cluster Autoscaler service account (null if disabled)"
  value       = try(aws_iam_role.cluster_autoscaler[0].arn, null)
}

output "aws_lb_controller_role_arn" {
  description = "IAM role ARN for AWS Load Balancer Controller service account (null if disabled)"
  value       = try(aws_iam_role.aws_lb_controller[0].arn, null)
}

output "loki_s3_role_arn" {
  description = "IAM role ARN for Loki S3 access service account (null if disabled)"
  value       = try(aws_iam_role.loki_s3[0].arn, null)
}

output "tempo_s3_role_arn" {
  description = "IAM role ARN for Tempo S3 access service account (null if disabled)"
  value       = try(aws_iam_role.tempo_s3[0].arn, null)
}

output "otel_xray_role_arn" {
  description = "IAM role ARN for OpenTelemetry X-Ray service account (null if disabled)"
  value       = try(aws_iam_role.otel_xray[0].arn, null)
}

output "ebs_csi_driver_role_arn" {
  description = "IAM role ARN for EBS CSI Driver service account (null if disabled)"
  value       = try(aws_iam_role.ebs_csi_driver[0].arn, null)
}

output "grafana_role_arn" {
  description = "IAM role ARN for Grafana service account (null if disabled)"
  value       = try(aws_iam_role.grafana[0].arn, null)
}