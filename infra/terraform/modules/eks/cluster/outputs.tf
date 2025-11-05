output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.this.name
}

output "cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = aws_eks_cluster.this.arn
}

output "cluster_endpoint" {
  description = "Endpoint URL of the EKS cluster API server"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_version" {
  description = "Kubernetes version of the EKS cluster"
  value       = aws_eks_cluster.this.version
}

output "cluster_platform_version" {
  description = "Platform version of the EKS cluster"
  value       = aws_eks_cluster.this.platform_version
}

output "cluster_ca_certificate" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_security_group_id" {
  description = "ID of the security group attached to the EKS cluster"
  value       = aws_security_group.cluster.id
}

output "cluster_iam_role_name" {
  description = "Name of the IAM role used by the EKS cluster"
  value       = aws_iam_role.cluster.name
}

output "cluster_iam_role_arn" {
  description = "ARN of the IAM role used by the EKS cluster"
  value       = aws_iam_role.cluster.arn
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC identity provider for the EKS cluster"
  value       = aws_iam_openid_connect_provider.this.arn
}

output "oidc_issuer_url" {
  description = "URL of the OIDC issuer for the EKS cluster"
  value       = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

output "region" {
  description = "AWS region where the EKS cluster is deployed"
  value       = data.aws_region.this.name
}