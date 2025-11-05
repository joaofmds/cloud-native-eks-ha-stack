variable "zone_name" {
  description = "Hosted zone DNS name (e.g., example.com)"
  type        = string
}

variable "comment" {
  description = "Comment/description for the hosted zone"
  type        = string
  default     = "Managed by Terraform"
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
  description = "Additional tags to be applied to all Route53 resources"
  type        = map(string)
  default     = {}
}

variable "create_public_zone" {
  description = "Create a public hosted zone"
  type        = bool
  default     = true
}

variable "existing_public_zone_id" {
  description = "Optional hosted zone ID of an existing public zone to manage"
  type        = string
  default     = null
}

variable "create_private_zone" {
  description = "Create a private hosted zone associated to one or more VPCs"
  type        = bool
  default     = false
}

variable "private_zone_vpc_associations" {
  description = "List of VPC associations for a private zone"
  type = list(object({
    vpc_id     = string
    vpc_region = optional(string)
  }))
  default = []
}

variable "enable_dnssec" {
  description = "Enable DNSSEC signing for the public zone"
  type        = bool
  default     = false
}

variable "dnssec_kms_key_arn" {
  description = "KMS CMK ARN for DNSSEC KSK (Route 53 requires a customer managed key). If null and enable_dnssec=true and create_dnssec_kms_key=true, the module will create one."
  type        = string
  default     = null
}

variable "create_dnssec_kms_key" {
  description = "Create a dedicated KMS key for DNSSEC if none provided"
  type        = bool
  default     = false
}

variable "enable_query_logging" {
  description = "Enable Route53 public query logging to CloudWatch Logs"
  type        = bool
  default     = false
}

variable "query_log_group_name" {
  description = "Name of the target CloudWatch Log Group for query logs"
  type        = string
  default     = null
}

variable "query_logs_kms_key_arn" {
  description = "(Optional) KMS key ARN for encrypting the log group"
  type        = string
  default     = null
}

variable "apex_alias" {
  description = "Alias target for the zone apex (A/AAAA) — typically an ALB/NLB/CloudFront. Set to null to skip."
  type = object({
    dns_name               = string
    zone_id                = string
    evaluate_target_health = optional(bool, false)
    create_aaaa            = optional(bool, true)
  })
  default = null
}

variable "additional_alias_records" {
  description = "List of additional alias records"
  type = list(object({
    name                   = string
    type                   = optional(string, "A")
    dns_name               = string
    zone_id                = string
    evaluate_target_health = optional(bool, false)
    create_aaaa            = optional(bool, true)
  }))
  default = []
}

variable "simple_records" {
  description = "List of simple (non-alias) records"
  type = list(object({
    name    = string
    type    = string
    ttl     = number
    records = list(string)
  }))
  default = []
}

variable "failover_records" {
  description = "List of failover records (primary/secondary)"
  type = list(object({
    name           = string
    type           = string
    set_identifier = string
    failover       = string
    ttl            = number
    records        = list(string)
    health_check = optional(object({
      fqdn              = string
      port              = number
      type              = string
      resource_path     = optional(string, "/")
      request_interval  = optional(number, 30)
      failure_threshold = optional(number, 3)
    }))
  }))
  default = []
}

variable "acm_validation_records" {
  description = "Map of validation record name => value (CNAME)"
  type        = map(string)
  default     = {}
}

variable "delegate_subdomains" {
  description = "Map of subdomain => list of NS target names"
  type        = map(list(string))
  default     = {}
}
