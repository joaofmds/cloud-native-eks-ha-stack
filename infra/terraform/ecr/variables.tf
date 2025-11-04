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
  description = "Additional tags to be applied to all ECR resources"
  type        = map(string)
  default     = {}
}

variable "repositories" {
  description = <<EOT
Map of ECR repositories to create.
Fields:
  name                       (string, optional)  — default: key
  immutable_tags             (bool)              — default: true
  scan_on_push               (bool)              — default: true
  kms_key_arn                (string, optional)  — if null uses AES-256 (default)
  image_tag_mutability       (string, optional)  — IMMUTABLE or MUTABLE (overrides immutable_tags when provided)
  force_delete               (bool, optional)    — allow deleting repo with images (labs)
  lifecycle_policy_json      (string, optional)  — full JSON of lifecycle
  lifecycle_keep_last        (number, optional)  — convenience: keep last N by pushedAt desc
  lifecycle_expire_untagged_days (number, optional) — convenience rule to expire untagged older than N days
  push_principal_arns        (list(string), optional) — IAM principals allowed to push (and pull)
  pull_principal_arns        (list(string), optional) — IAM principals allowed to pull
  restrict_to_private_subnets(bool, optional)   — N/A to ECR; kept for API symmetry (ignored)
EOT
  type = map(object({
    name                           = optional(string)
    immutable_tags                 = optional(bool, true)
    scan_on_push                   = optional(bool, true)
    kms_key_arn                    = optional(string)
    image_tag_mutability           = optional(string)
    force_delete                   = optional(bool, false)
    lifecycle_policy_json          = optional(string)
    lifecycle_keep_last            = optional(number)
    lifecycle_expire_untagged_days = optional(number)
    push_principal_arns            = optional(list(string), [])
    pull_principal_arns            = optional(list(string), [])
    restrict_to_private_subnets    = optional(bool, false)
  }))
  default = {}
}

variable "enable_registry_enhanced_scanning" {
  description = "Enable enhanced scanning for all repositories in the registry"
  type        = bool
  default     = true
}
variable "registry_scan_rules" {
  description = "Optional registry scanning rules JSON. If null, provider default rules apply."
  type        = string
  default     = null
}

variable "replication_rules" {
  description = <<EOT
List of replication rules. If empty, replication is disabled.
Each rule:
  destinations: list(object({ region=string, registry_id=optional(string) })) — registry_id for cross‑account
  repository_filter: optional(object({ prefix=string })) — defaults to '*' (all repositories)
EOT
  type = list(object({
    destinations      = list(object({ region = string, registry_id = optional(string) }))
    repository_filter = optional(object({ prefix = string }), null)
  }))
  default = []
}

variable "registry_policy_json" {
  type        = string
  default     = null
  description = "If set, applies a registry policy at the account level. Use sparingly."
}