variable "name_prefix" {
  description = "Prefix used for alias and tags naming"
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
  description = "Additional tags to be applied to all KMS resources"
  type        = map(string)
  default     = {}
}

variable "keys" {
  description = <<EOT
Map of keys to create. Each value supports:
  description             (string)  — human description
  alias                   (string)  — alias without 'alias/' prefix (e.g., 'k-logs', 'k-loki')
  multi_region            (bool)    — multi-Region key (MRK)
  enable_rotation         (bool)    — automatic annual rotation
  deletion_window_days    (number)  — 7..30
  admins_iam_arns         (list)    — additional IAM principals with full admin on the key
  users_iam_arns          (list)    — principals allowed to encrypt/decrypt (beyond admin)
  cloudwatch_logs_arns    (list)    — OPTIONAL list of log group ARNs that may use the key
  cloudtrail_trail_arns   (list)    — OPTIONAL list of CloudTrail trail ARNs that may use the key
  allow_cross_account_arns(list)    — OPTIONAL external account root/user/role ARNs to share usage
EOT
  type = map(object({
    description              = optional(string, "")
    alias                    = string
    multi_region             = optional(bool, false)
    enable_rotation          = optional(bool, true)
    deletion_window_days     = optional(number, 30)
    admins_iam_arns          = optional(list(string), [])
    users_iam_arns           = optional(list(string), [])
    cloudwatch_logs_arns     = optional(list(string), [])
    cloudtrail_trail_arns    = optional(list(string), [])
    allow_cross_account_arns = optional(list(string), [])
  }))
  default = {}
}