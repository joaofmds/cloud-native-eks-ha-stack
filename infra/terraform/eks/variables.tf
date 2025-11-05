# ── EKS Cluster Configuration ──────────────────────────────────────────

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster (e.g., 1.32)"
  type        = string
}

variable "project" {
  description = "Project name used for resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod) used for resource naming and tagging"
  type        = string
}

variable "owner" {
  description = "Owner of the resources, used for resource tagging"
  type        = string
}

variable "tags" {
  description = "Additional tags to be applied to all EKS resources"
  type        = map(string)
  default     = {}
}

# ── Network Configuration ──────────────────────────────────────────────

variable "vpc_id" {
  description = "VPC ID where the EKS cluster will be created"
  type        = string
}

variable "cluster_subnet_ids" {
  description = "Subnet IDs for EKS control plane ENIs (usually private subnets)"
  type        = list(string)
}

variable "nodegroup_subnet_ids" {
  description = "Subnet IDs for EKS node groups (usually private subnets)"
  type        = list(string)
}

# ── Cluster Access Configuration ───────────────────────────────────────

variable "public_subnet_cidr_blocks" {
  description = "CIDR blocks for public subnets that will host load balancers"
  type        = list(string)
  default     = []
}

variable "vpc_cidr_block" {
  description = "Primary CIDR block associated with the VPC"
  type        = string
}

variable "endpoint_public_access" {
  description = "Enable public endpoint access for the EKS cluster API"
  type        = bool
  default     = false
}

variable "endpoint_public_access_cidrs" {
  description = "List of CIDR blocks that can access the public API server endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "endpoint_private_access" {
  description = "Enable private endpoint access for the EKS cluster API"
  type        = bool
  default     = true
}

# ── Cluster Security & Encryption ──────────────────────────────────────

variable "cluster_log_types" {
  description = "List of control plane log types to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "secrets_kms_key_arn" {
  description = "ARN of KMS key for encrypting Kubernetes secrets"
  type        = string
  default     = null
}

variable "security_group_additional_ingress" {
  description = "Additional ingress rules for the cluster security group"
  type = list(object({
    description = optional(string, "custom")
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = optional(list(string), [])
    sg_ids      = optional(list(string), [])
  }))
  default = []
}

# ── Core Add-ons Configuration ─────────────────────────────────────────

variable "enable_core_addons" {
  description = "Enable core EKS add-ons (VPC-CNI, CoreDNS, kube-proxy)"
  type        = bool
  default     = true
}

variable "addon_vpc_cni_version" {
  description = "Version of the VPC-CNI add-on (if null, uses EKS default)"
  type        = string
  default     = null
}

variable "addon_coredns_version" {
  description = "Version of the CoreDNS add-on (if null, uses EKS default)"
  type        = string
  default     = null
}

variable "addon_kube_proxy_version" {
  description = "Version of the kube-proxy add-on (if null, uses EKS default)"
  type        = string
  default     = null
}

# ── Access Control ─────────────────────────────────────────────────────

variable "eks_admin_principal_arns" {
  description = "List of IAM principal ARNs to grant cluster admin access via EKS access entries"
  type        = list(string)
  default     = []
}

variable "eks_view_principal_arns" {
  description = "List of IAM principal ARNs to grant read-only access via EKS access entries"
  type        = list(string)
  default     = []
}

# ── Node Groups Configuration ──────────────────────────────────────────

variable "enable_nodegroups" {
  description = "Enable creation of EKS node groups"
  type        = bool
  default     = true
}

variable "nodegroups" {
  description = <<EOT
Map of node group configurations. Each key represents a node group name.
Example:
{
  "general" = {
    capacity_type    = "ON_DEMAND"
    instance_types   = ["m5.large"]
    ami_family       = "AL2"
    min_size         = 1
    max_size         = 3
    desired_size     = 2
  }
  "spot" = {
    capacity_type    = "SPOT"
    instance_types   = ["m5.large", "m5.xlarge"]
    ami_family       = "AL2"
    min_size         = 0
    max_size         = 10
    desired_size     = 3
  }
}

Available fields:
- name                    (string, optional) - Custom name override
- capacity_type          (string) - "ON_DEMAND" or "SPOT"
- instance_types         (list(string)) - EC2 instance types
- ami_family             (string) - "AL2" or "BOTTLEROCKET"
- ami_type_override      (string, optional) - Explicit AMI type override
- disk_size              (number, optional) - Root volume size in GiB
- min_size               (number) - Minimum number of nodes
- max_size               (number) - Maximum number of nodes
- desired_size           (number, optional) - Desired number of nodes
- update_max_unavailable (number, optional) - Max nodes unavailable during update
- update_max_unavailable_percentage (number, optional) - Max percentage unavailable
- labels                 (map(string), optional) - Kubernetes labels
- taints                 (list(object), optional) - Kubernetes taints
- enable_ssm             (bool, optional) - Enable AWS Systems Manager
- launch_template        (object, optional) - Custom launch template
- additional_policies_arns (list(string), optional) - Additional IAM policies
- node_role_name_override (string, optional) - Use existing IAM role
- remote_access          (object, optional) - SSH access configuration
EOT
  type = map(object({
    name                              = optional(string)
    capacity_type                     = string
    instance_types                    = list(string)
    ami_family                        = optional(string, "AL2")
    ami_type_override                 = optional(string)
    disk_size                         = optional(number, 40)
    min_size                          = number
    max_size                          = number
    desired_size                      = optional(number)
    update_max_unavailable            = optional(number)
    update_max_unavailable_percentage = optional(number)
    labels                            = optional(map(string), {})
    taints = optional(list(object({
      key    = string
      value  = optional(string)
      effect = string
    })), [])
    enable_ssm = optional(bool, false)
    launch_template = optional(object({
      id      = string
      version = string
    }))
    additional_policies_arns = optional(list(string), [])
    node_role_name_override  = optional(string)
    remote_access = optional(object({
      enabled                   = bool
      ec2_key_name              = optional(string)
      source_security_group_ids = optional(list(string), [])
    }), { enabled = false })
  }))
  default = {}
}
