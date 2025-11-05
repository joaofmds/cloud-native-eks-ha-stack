variable "name_prefix" {
  description = "Prefix for bucket name and tags"
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
  description = "Additional tags to be applied to all S3 resources"
  type        = map(string)
  default     = {}
}

variable "bucket_name" {
  description = "Optional explicit bucket name. If null, a name will be generated using name_prefix and account/region."
  type        = string
  default     = null
}

variable "kms_key_arn" {
  description = "KMS key ARN for SSE-KMS. If null, use SSE-S3."
  type        = string
  default     = null
}

variable "versioning" {
  description = "Enable versioning on the bucket"
  type        = bool
  default     = true
}

variable "force_destroy" {
  description = "Allow force destroy for lab/teardown"
  type        = bool
  default     = false
}

variable "access_logging" {
  description = "Enable server access logging to a target bucket/prefix"
  type = object({
    enabled       = bool
    target_bucket = optional(string)
    target_prefix = optional(string, "access-logs/")
  })
  default = {
    enabled = false
  }
}

variable "allowed_role_arns" {
  description = "Principals (IRSA roles) allowed to read/write traces"
  type        = list(string)
  default     = []
}

variable "retention_days" {
  description = "Optional retention period (in days) for Tempo trace data"
  type        = number
  default     = 7
}

variable "deny_insecure_transport" {
  description = "Deny non-SSL requests via bucket policy"
  type        = bool
  default     = true
}

variable "require_sse_kms" {
  description = "If true, deny PutObject that doesn't specify AWS KMS encryption with this bucket's KMS key"
  type        = bool
  default     = false
}
