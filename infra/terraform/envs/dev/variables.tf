variable "aws_region" {
  description = "AWS region used for all resources"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project tag used for resources"
  type        = string
  default     = "cloud-native-eks-ha-stack"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Owner or team responsible for the stack"
  type        = string
  default     = "platform-team"
}

variable "tags" {
  description = "Additional tags applied across modules"
  type        = map(string)
  default     = {}
}

variable "vpc_cidr_block" {
  description = "CIDR block for the primary VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "vpc_az_count" {
  description = "Number of availability zones to span"
  type        = number
  default     = 3
}

variable "vpc_subnet_newbits" {
  description = "Newbits value used when deriving subnet CIDRs"
  type        = number
  default     = 4
}

variable "vpc_nat_gateway_strategy" {
  description = "Strategy for NAT gateways (one_per_az or single)"
  type        = string
  default     = "single"
}

variable "vpc_create_intra_subnets" {
  description = "Whether to create intra (no egress) subnets"
  type        = bool
  default     = true
}

variable "vpc_create_database_subnets" {
  description = "Whether to create database subnets"
  type        = bool
  default     = false
}

variable "vpc_enable_ipv6" {
  description = "Assign an IPv6 CIDR to the VPC"
  type        = bool
  default     = false
}

variable "vpc_enable_s3_gateway_endpoint" {
  description = "Provision the S3 gateway endpoint"
  type        = bool
  default     = true
}

variable "vpc_enable_dynamodb_gateway_endpoint" {
  description = "Provision the DynamoDB gateway endpoint"
  type        = bool
  default     = true
}

variable "vpc_interface_endpoints" {
  description = "Interface endpoints to provision inside the VPC"
  type        = list(string)
  default     = ["ecr.api", "ecr.dkr", "logs", "ssm", "ssmmessages", "ec2messages"]
}

variable "vpc_flow_logs_destination_type" {
  description = "Destination for flow logs (s3 or cloudwatch)"
  type        = string
  default     = "s3"
}

variable "vpc_flow_logs_s3_arn" {
  description = "Optional S3 bucket ARN used for flow logs"
  type        = string
  default     = null
}

variable "vpc_flow_logs_cw_retention_days" {
  description = "CloudWatch log retention when using cloudwatch destination"
  type        = number
  default     = 30
}

variable "vpc_flow_logs_kms_key_arn" {
  description = "KMS key ARN for encrypting flow logs"
  type        = string
  default     = null
}

variable "eks_cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "dev-eks"
}

variable "eks_cluster_version" {
  description = "Kubernetes version for the EKS control plane"
  type        = string
  default     = "1.32"
}

variable "eks_endpoint_public_access" {
  description = "Expose the Kubernetes API publicly"
  type        = bool
  default     = false
}

variable "eks_endpoint_public_access_cidrs" {
  description = "Allowed CIDRs when public access is enabled"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "eks_endpoint_private_access" {
  description = "Enable the private control plane endpoint"
  type        = bool
  default     = true
}

variable "eks_enable_core_addons" {
  description = "Install the managed VPC CNI, CoreDNS and kube-proxy add-ons"
  type        = bool
  default     = true
}

variable "eks_cluster_log_types" {
  description = "Control plane log types to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "eks_secrets_kms_key_arn" {
  description = "Optional KMS key ARN for secrets encryption"
  type        = string
  default     = null
}

variable "eks_security_group_additional_ingress" {
  description = "Additional security group ingress rules for the cluster"
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

variable "eks_admin_principal_arns" {
  description = "Principal ARNs granted admin access"
  type        = list(string)
  default     = []
}

variable "eks_view_principal_arns" {
  description = "Principal ARNs granted read-only access"
  type        = list(string)
  default     = []
}

variable "eks_enable_nodegroups" {
  description = "Create managed node groups"
  type        = bool
  default     = true
}

variable "eks_nodegroups" {
  description = "Managed node group definitions"
  type = map(object({
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
  default = {
    general = {
      capacity_type   = "ON_DEMAND"
      instance_types  = ["t3.large"]
      min_size        = 1
      max_size        = 3
      desired_size    = 2
      disk_size       = 40
      enable_ssm      = true
      labels          = { role = "general" }
      update_max_unavailable = 1
    }
  }
}

variable "route53_zone_name" {
  description = "DNS zone name managed by Route53"
  type        = string
  default     = "dev.internal"
}

variable "route53_create_public_zone" {
  description = "Create a public hosted zone"
  type        = bool
  default     = false
}

variable "route53_existing_public_zone_id" {
  description = "Hosted zone ID of an existing public zone to manage"
  type        = string
  default     = null
}

variable "route53_create_private_zone" {
  description = "Create a private hosted zone"
  type        = bool
  default     = true
}

variable "route53_enable_dnssec" {
  description = "Enable DNSSEC for the public zone"
  type        = bool
  default     = false
}

variable "route53_enable_query_logging" {
  description = "Enable query logging for the public zone"
  type        = bool
  default     = false
}

variable "route53_additional_private_zone_associations" {
  description = "Additional VPC associations for the private zone"
  type = list(object({
    vpc_id     = string
    vpc_region = optional(string)
  }))
  default = []
}

variable "s3_loki_bucket_name" {
  description = "Optional override for the Loki S3 bucket name"
  type        = string
  default     = null
}

variable "s3_loki_enable_versioning" {
  description = "Enable versioning on the Loki bucket"
  type        = bool
  default     = true
}

variable "s3_loki_force_destroy" {
  description = "Allow force destroy of the Loki bucket"
  type        = bool
  default     = false
}

variable "s3_loki_kms_key_arn" {
  description = "KMS key ARN for bucket encryption"
  type        = string
  default     = null
}

variable "s3_tempo_bucket_name" {
  description = "Optional override for the Tempo S3 bucket name"
  type        = string
  default     = null
}

variable "s3_tempo_enable_versioning" {
  description = "Enable versioning on the Tempo bucket"
  type        = bool
  default     = true
}

variable "s3_tempo_force_destroy" {
  description = "Allow force destroy of the Tempo bucket"
  type        = bool
  default     = false
}

variable "s3_tempo_kms_key_arn" {
  description = "KMS key ARN for Tempo bucket encryption"
  type        = string
  default     = null
}

variable "s3_tempo_retention_days" {
  description = "Lifecycle retention (in days) for Tempo traces"
  type        = number
  default     = 7
}

variable "iam_generic_irsa_roles" {
  description = "Additional generic IRSA roles"
  type        = map(any)
  default     = {}
}

variable "iam_enable_external_dns" {
  description = "Create an ExternalDNS IRSA role"
  type        = bool
  default     = true
}

variable "iam_external_dns_namespace" {
  description = "Namespace for the ExternalDNS service account"
  type        = string
  default     = "external-dns"
}

variable "iam_external_dns_service_account" {
  description = "Service account name for ExternalDNS"
  type        = string
  default     = "external-dns"
}

variable "iam_external_dns_zone_ids" {
  description = "Hosted zone IDs ExternalDNS can manage"
  type        = list(string)
  default     = []
}

variable "iam_enable_cert_manager" {
  description = "Create a cert-manager IRSA role"
  type        = bool
  default     = true
}

variable "iam_cert_manager_namespace" {
  description = "Namespace for the cert-manager service account"
  type        = string
  default     = "cert-manager"
}

variable "iam_cert_manager_service_account" {
  description = "Service account name for cert-manager"
  type        = string
  default     = "cert-manager"
}

variable "iam_cert_manager_zone_ids" {
  description = "Hosted zone IDs cert-manager can manage"
  type        = list(string)
  default     = []
}

variable "iam_enable_cluster_autoscaler" {
  description = "Create a Cluster Autoscaler IRSA role"
  type        = bool
  default     = true
}

variable "iam_cluster_autoscaler_namespace" {
  description = "Namespace for the Cluster Autoscaler service account"
  type        = string
  default     = "kube-system"
}

variable "iam_cluster_autoscaler_service_account" {
  description = "Service account name for the Cluster Autoscaler"
  type        = string
  default     = "cluster-autoscaler"
}

variable "iam_enable_load_balancer_controller" {
  description = "Create an AWS Load Balancer Controller IRSA role"
  type        = bool
  default     = true
}

variable "iam_load_balancer_controller_namespace" {
  description = "Namespace for the AWS Load Balancer Controller"
  type        = string
  default     = "kube-system"
}

variable "iam_load_balancer_controller_service_account" {
  description = "Service account name for the AWS Load Balancer Controller"
  type        = string
  default     = "aws-load-balancer-controller"
}

variable "iam_enable_loki_s3" {
  description = "Create an IRSA role for Loki access to S3"
  type        = bool
  default     = true
}

variable "iam_loki_namespace" {
  description = "Namespace containing Loki pods"
  type        = string
  default     = "monitoring"
}

variable "iam_loki_service_accounts" {
  description = "Service accounts that require S3 access"
  type        = list(string)
  default     = ["loki"]
}

variable "iam_enable_tempo_s3" {
  description = "Create an IRSA role for Tempo"
  type        = bool
  default     = true
}

variable "iam_tempo_namespace" {
  description = "Namespace containing Tempo pods"
  type        = string
  default     = "monitoring"
}

variable "iam_tempo_service_accounts" {
  description = "Service accounts that require Tempo S3 access"
  type        = list(string)
  default     = ["tempo"]
}

variable "iam_enable_otel_xray" {
  description = "Create an IRSA role for the OpenTelemetry collector"
  type        = bool
  default     = false
}

variable "iam_otel_namespace" {
  description = "Namespace for the OpenTelemetry collector"
  type        = string
  default     = "monitoring"
}

variable "iam_otel_service_account" {
  description = "Service account name for the OpenTelemetry collector"
  type        = string
  default     = "otel-collector"
}

variable "iam_enable_ebs_csi_driver" {
  description = "Create an IRSA role for the AWS EBS CSI driver"
  type        = bool
  default     = true
}

variable "iam_ebs_csi_driver_namespace" {
  description = "Namespace for the EBS CSI driver controller"
  type        = string
  default     = "kube-system"
}

variable "iam_ebs_csi_driver_service_account" {
  description = "Service account for the EBS CSI driver controller"
  type        = string
  default     = "ebs-csi-controller-sa"
}

variable "eks_enable_ebs_csi_driver" {
  description = "Install the AWS EBS CSI managed addon"
  type        = bool
  default     = true
}

variable "eks_ebs_csi_driver_version" {
  description = "Optional version override for the AWS EBS CSI addon"
  type        = string
  default     = null
}
