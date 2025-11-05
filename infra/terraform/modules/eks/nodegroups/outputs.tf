output "nodegroup_names" {
  description = "Map of node group keys to their actual names in EKS"
  value       = { for k, ng in aws_eks_node_group.this : k => ng.node_group_name }
}

output "nodegroup_arns" {
  description = "Map of node group keys to their ARNs"
  value       = { for k, ng in aws_eks_node_group.this : k => ng.arn }
}

output "nodegroup_status" {
  description = "Map of node group keys to their current status"
  value       = { for k, ng in aws_eks_node_group.this : k => ng.status }
}

output "node_roles" {
  description = "Map of node group keys to their IAM role ARNs"
  value       = { for k, r in aws_iam_role.node : k => r.arn }
}

output "node_role_names" {
  description = "Map of node group keys to their IAM role names"
  value       = { for k, r in aws_iam_role.node : k => r.name }
}

output "instance_profiles" {
  description = "Map of node group keys to their EC2 instance profile ARNs"
  value       = { for k, p in aws_iam_instance_profile.node : k => p.arn }
}

output "instance_profile_names" {
  description = "Map of node group keys to their EC2 instance profile names"
  value       = { for k, p in aws_iam_instance_profile.node : k => p.name }
}

output "nodegroup_capacity_types" {
  description = "Map of node group keys to their capacity types (ON_DEMAND or SPOT)"
  value       = { for k, ng in aws_eks_node_group.this : k => ng.capacity_type }
}

output "nodegroup_instance_types" {
  description = "Map of node group keys to their instance types"
  value       = { for k, ng in aws_eks_node_group.this : k => ng.instance_types }
}

output "nodegroup_ami_types" {
  description = "Map of node group keys to their AMI types"
  value       = { for k, ng in aws_eks_node_group.this : k => ng.ami_type }
}

output "nodegroup_scaling_configs" {
  description = "Map of node group keys to their scaling configuration"
  value = { for k, ng in aws_eks_node_group.this :
    k => {
      min_size     = ng.scaling_config[0].min_size
      max_size     = ng.scaling_config[0].max_size
      desired_size = try(ng.scaling_config[0].desired_size, null)
    }
  }
}

output "total_min_nodes" {
  description = "Total minimum number of nodes across all node groups"
  value       = sum([for ng in aws_eks_node_group.this : ng.scaling_config[0].min_size])
}

output "total_max_nodes" {
  description = "Total maximum number of nodes across all node groups"
  value       = sum([for ng in aws_eks_node_group.this : ng.scaling_config[0].max_size])
}

output "total_desired_nodes" {
  description = "Total desired number of nodes across all node groups"
  value       = sum([for ng in aws_eks_node_group.this : try(ng.scaling_config[0].desired_size, ng.scaling_config[0].min_size)])
}

output "launch_template_ids" {
  description = "Map of node group keys to their launch template IDs (managed or provided)"
  value = { for k, lt in local.effective_launch_templates : k => try(lt.id, null) }
}

output "launch_template_versions" {
  description = "Map of node group keys to their launch template versions (managed or provided)"
  value = { for k, lt in local.effective_launch_templates : k => try(lt.version, null) }
}