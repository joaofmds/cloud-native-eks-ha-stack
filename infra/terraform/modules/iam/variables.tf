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
  description = "Additional tags to be applied to all IAM IRSA resources"
  type        = map(string)
  default     = {}
}

variable "cluster_name" {
  description = "EKS cluster name (used by some preset policies like cluster-autoscaler)"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of aws_iam_openid_connect_provider for the cluster"
  type        = string
}

variable "oidc_issuer_url" {
  description = "Issuer URL (e.g., https://oidc.eks.<region>.amazonaws.com/id/XXXXXXXXXX)"
  type        = string
}

variable "generic_irsa_roles" {
  description = "Map of generic IRSA roles to create with custom policies and service accounts"
  type = map(object({
    description         = optional(string, "")
    namespace           = string
    service_accounts    = list(string)
    policy_json         = optional(string)
    managed_policy_arns = optional(list(string), [])
    name_override       = optional(string)
  }))
  default = {}
}

variable "enable_external_dns" {
  description = "Enable IRSA role for External DNS to manage Route53 records"
  type        = bool
  default     = false
}

variable "external_dns" {
  description = "Configuration for External DNS IRSA role"
  type = object({
    namespace       = optional(string, "kube-system")
    service_account = optional(string, "external-dns")
    zone_ids        = optional(list(string), []) # scope changes to specific hosted zones; empty = all (not recommended)
  })
  default = {}
}

variable "enable_cert_manager" {
  description = "Enable IRSA role for Cert Manager to manage SSL certificates via Route53 DNS validation"
  type        = bool
  default     = false
}

variable "cert_manager" {
  description = "Configuration for Cert Manager IRSA role"
  type = object({
    namespace       = optional(string, "cert-manager")
    service_account = optional(string, "cert-manager")
    zone_ids        = optional(list(string), [])
  })
  default = {}
}

variable "enable_cluster_autoscaler" {
  description = "Enable IRSA role for Cluster Autoscaler to manage EKS node groups"
  type        = bool
  default     = false
}

variable "cluster_autoscaler" {
  description = "Configuration for Cluster Autoscaler IRSA role"
  type = object({
    namespace       = optional(string, "kube-system")
    service_account = optional(string, "cluster-autoscaler")
  })
  default = {}
}

variable "enable_aws_load_balancer_controller" {
  description = "Enable IRSA role for AWS Load Balancer Controller to manage ALB/NLB"
  type        = bool
  default     = false
}

variable "aws_load_balancer_controller" {
  description = "Configuration for AWS Load Balancer Controller IRSA role"
  type = object({
    namespace       = optional(string, "kube-system")
    service_account = optional(string, "aws-load-balancer-controller")
  })
  default = {}
}

variable "enable_loki_s3" {
  description = "Enable IRSA role for Loki to access S3 bucket for log storage"
  type        = bool
  default     = false
}

variable "loki_s3" {
  description = "Configuration for Loki S3 IRSA role"
  type = object({
    namespace        = optional(string, "observability")
    service_accounts = optional(list(string), ["loki"]) # ingester, querier, ruler etc. if split
    bucket_arn       = string
  })
  default = null
}

variable "enable_tempo_s3" {
  description = "Enable IRSA role for Tempo to access S3 bucket for trace storage"
  type        = bool
  default     = false
}

variable "tempo_s3" {
  description = "Configuration for Tempo S3 IRSA role"
  type = object({
    namespace        = optional(string, "observability")
    service_accounts = optional(list(string), ["tempo"])
    bucket_arn       = string
  })
  default = null
}

variable "enable_otel_xray" {
  description = "Enable IRSA role for OpenTelemetry Collector to send traces to AWS X-Ray"
  type        = bool
  default     = false
}

variable "otel_xray" {
  description = "Configuration for OpenTelemetry X-Ray IRSA role"
  type = object({
    namespace       = optional(string, "observability")
    service_account = optional(string, "otel-collector")
  })
  default = null
}

variable "enable_ebs_csi_driver" {
  description = "Enable IRSA role for the AWS EBS CSI driver"
  type        = bool
  default     = false
}

variable "ebs_csi_driver" {
  description = "Configuration for the AWS EBS CSI driver IRSA role"
  type = object({
    namespace       = optional(string, "kube-system")
    service_account = optional(string, "ebs-csi-controller-sa")
  })
  default = null
}

variable "enable_grafana_s3" {
  description = "Enable IRSA role for Grafana"
  type        = bool
  default     = false
}

variable "grafana" {
  description = "Configuration for Grafana IRSA role"
  type = object({
    namespace       = optional(string, "monitoring")
    service_account = optional(string, "kube-prometheus-stack-grafana")
  })
  default = null
}

variable "grafana_s3" {
  description = "S3 bucket for Grafana (optional)"
  type = object({
    bucket_arn = string
  })
  default = null
}