# ── EKS Cluster Outputs ───────────────────────────────────────────────

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.cluster.cluster_name
}

output "cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = var.enable_nodegroups ? module.cluster.cluster_arn : null
}

output "cluster_endpoint" {
  description = "Endpoint URL of the EKS cluster API server"
  value       = var.enable_nodegroups ? module.cluster.cluster_endpoint : null
  sensitive   = true
}

output "cluster_version" {
  description = "Kubernetes version of the EKS cluster"
  value       = var.enable_nodegroups ? module.cluster.cluster_version : null
}

output "cluster_platform_version" {
  description = "Platform version for the EKS cluster"
  value       = var.enable_nodegroups ? module.cluster.cluster_platform_version : null
}

output "cluster_status" {
  description = "Status of the EKS cluster (CREATING, ACTIVE, DELETING, FAILED)"
  value       = var.enable_nodegroups ? module.cluster.cluster_status : null
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = var.enable_nodegroups ? module.cluster.cluster_certificate_authority_data : null
  sensitive   = true
}

# ── OIDC Provider Outputs ─────────────────────────────────────────────

output "oidc_provider_arn" {
  description = "ARN of the OIDC Identity Provider associated with the EKS cluster"
  value       = module.cluster.oidc_provider_arn
}

output "oidc_provider_url" {
  description = "URL of the OIDC Identity Provider associated with the EKS cluster"
  value       = module.cluster.oidc_provider_url
}

# ── Cluster Security Outputs ──────────────────────────────────────────

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = var.enable_nodegroups ? module.cluster.cluster_security_group_id : null
}

output "node_security_group_id" {
  description = "Security group ID associated with the managed node groups"
  value       = local.create_nodegroups ? aws_security_group.nodes[0].id : null
}

output "cluster_iam_role_arn" {
  description = "IAM role ARN associated with the EKS cluster"
  value       = var.enable_nodegroups ? module.cluster.cluster_iam_role_arn : null
}

output "cluster_iam_role_name" {
  description = "IAM role name associated with the EKS cluster"
  value       = var.enable_nodegroups ? module.cluster.cluster_iam_role_name : null
}

# ── Node Groups Outputs ───────────────────────────────────────────────

output "nodegroup_names" {
  description = "List of EKS node group names"
  value       = var.enable_nodegroups ? keys(module.nodegroups[0].nodegroup_names) : []
}

output "nodegroup_arns" {
  description = "Map of node group names to their ARNs"
  value       = var.enable_nodegroups ? module.nodegroups[0].nodegroup_arns : {}
}

output "nodegroup_statuses" {
  description = "Map of node group names to their current status"
  value       = var.enable_nodegroups ? module.nodegroups[0].nodegroup_status : {}
}

output "nodegroup_capacity_types" {
  description = "Map of node group names to their capacity types (ON_DEMAND/SPOT)"
  value       = var.enable_nodegroups ? module.nodegroups[0].nodegroup_capacity_types : {}
}

output "nodegroup_instance_types" {
  description = "Map of node group names to their instance types"
  value       = var.enable_nodegroups ? module.nodegroups[0].nodegroup_instance_types : {}
}

output "nodegroup_ami_types" {
  description = "Map of node group names to their AMI types"
  value       = var.enable_nodegroups ? module.nodegroups[0].nodegroup_ami_types : {}
}

output "node_roles" {
  description = "Map of node group names to their IAM role ARNs"
  value       = var.enable_nodegroups ? module.nodegroups[0].node_roles : {}
}

output "node_role_names" {
  description = "Map of node group names to their IAM role names"
  value       = var.enable_nodegroups ? module.nodegroups[0].node_role_names : {}
}

output "launch_template_ids" {
  description = "Map of node group names to their launch template IDs (if custom launch templates are used)"
  value       = var.enable_nodegroups ? module.nodegroups[0].launch_template_ids : {}
}

output "launch_template_versions" {
  description = "Map of node group names to their launch template versions (if custom launch templates are used)"
  value       = var.enable_nodegroups ? module.nodegroups[0].launch_template_versions : {}
}

# ── Scaling Information ───────────────────────────────────────────────

output "nodegroup_scaling_configs" {
  description = "Map of node group names to their scaling configurations (min_size, max_size, desired_size)"
  value       = var.enable_nodegroups ? module.nodegroups[0].nodegroup_scaling_configs : {}
}

output "total_min_nodes" {
  description = "Total minimum number of nodes across all node groups"
  value       = var.enable_nodegroups ? module.nodegroups[0].total_min_nodes : 0
}

output "total_max_nodes" {
  description = "Total maximum number of nodes across all node groups"
  value       = var.enable_nodegroups ? module.nodegroups[0].total_max_nodes : 0
}

output "total_desired_nodes" {
  description = "Total desired number of nodes across all node groups"
  value       = var.enable_nodegroups ? module.nodegroups[0].total_desired_nodes : 0
}

# ── Cluster Connection Information ────────────────────────────────────

output "kubectl_config" {
  description = "kubectl configuration for connecting to the EKS cluster"
  value = var.enable_nodegroups ? {
    cluster_name     = module.cluster.cluster_name
    cluster_endpoint = module.cluster.cluster_endpoint
    cluster_ca_data  = module.cluster.cluster_certificate_authority_data
    region           = data.aws_region.current.id
  } : null
  sensitive = true
}

output "cluster_auth_command" {
  description = "AWS CLI command to configure kubectl authentication"
  value       = var.enable_nodegroups ? "aws eks update-kubeconfig --region ${data.aws_region.current.id} --name ${module.cluster.cluster_name}" : null
}

# ── Tags Output ───────────────────────────────────────────────────────

output "common_tags" {
  description = "Common tags applied to all EKS resources"
  value = {
    Project     = var.project
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "terraform"
    Module      = "eks"
  }
}

# ── Data Sources for Context ──────────────────────────────────────────

output "aws_account_id" {
  description = "AWS Account ID where the EKS cluster is deployed"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS Region where the EKS cluster is deployed"
  value       = data.aws_region.current.id
}
