output "vpc_id" {
  description = "Identifier of the provisioned VPC"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet identifiers used by the EKS cluster"
  value       = module.vpc.private_subnet_ids
}

output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Endpoint URL for the EKS control plane"
  value       = module.eks.cluster_endpoint
  sensitive   = true
}

output "eks_oidc_provider_arn" {
  description = "OIDC provider ARN backing IRSA roles"
  value       = module.eks.oidc_provider_arn
}

output "loki_bucket_name" {
  description = "S3 bucket that stores Loki logs"
  value       = module.s3_loki.bucket_name
}

output "tempo_bucket_name" {
  description = "S3 bucket that stores Tempo traces"
  value       = module.s3_tempo.bucket_name
}

output "route53_private_zone_id" {
  description = "ID of the private Route53 hosted zone"
  value       = module.route53.private_zone_id
}

output "route53_public_zone_id" {
  description = "ID of the public Route53 hosted zone"
  value       = module.route53.public_zone_id
}

output "cluster_autoscaler_role_arn" {
  description = "IAM role ARN used by the Cluster Autoscaler"
  value       = module.iam.cluster_autoscaler_role_arn
}

output "aws_lb_controller_role_arn" {
  description = "IAM role ARN for the AWS Load Balancer Controller"
  value       = module.iam.aws_lb_controller_role_arn
}

output "loki_s3_role_arn" {
  description = "IAM role ARN that grants Loki access to S3"
  value       = module.iam.loki_s3_role_arn
}

output "tempo_s3_role_arn" {
  description = "IAM role ARN that grants Tempo access to S3"
  value       = module.iam.tempo_s3_role_arn
}

output "external_dns_role_arn" {
  description = "IAM role ARN for ExternalDNS"
  value       = module.iam.external_dns_role_arn
}

output "cert_manager_role_arn" {
  description = "IAM role ARN for cert-manager"
  value       = module.iam.cert_manager_role_arn
}

output "ebs_csi_driver_role_arn" {
  description = "IAM role ARN used by the AWS EBS CSI driver"
  value       = module.iam.ebs_csi_driver_role_arn
}
