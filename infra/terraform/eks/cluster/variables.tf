variable "name" {
  description = "EKS cluster name"
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
  description = "Additional tags to be applied to all EKS cluster resources"
  type        = map(string)
  default     = {}
}

variable "version" {
  description = "EKS Kubernetes version (e.g., 1.32)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the EKS cluster will be created"
  type        = string
}
variable "subnet_ids" {
  description = "Subnets for EKS control plane ENIs (usually private)"
  type        = list(string)
}

variable "endpoint_public_access" {
  description = "Enable public endpoint access"
  type        = bool
  default     = false
}

variable "endpoint_public_access_cidrs" {
  description = "CIDRs allowed to reach the public endpoint (used if endpoint_public_access=true)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "endpoint_private_access" {
  description = "Enable private endpoint access"
  type        = bool
  default     = true
}

variable "cluster_log_types" {
  description = "Control plane log types to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "secrets_kms_key_arn" {
  description = "KMS key ARN for Secrets encryption (EKS encryption_config)"
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

variable "node_security_group_id" {
  description = "Security group ID of the worker nodes to allow API server access"
  type        = string
  default     = null
}

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

variable "eks_admin_principal_arns" {
  type        = list(string)
  default     = []
  description = "IAM ARNs to grant cluster admin access via EKS access entries"
}

variable "eks_view_principal_arns" {
  type        = list(string)
  default     = []
  description = "IAM ARNs to grant read-only access via EKS access entries"
}