variable "cluster_name" {
  description = "EKS cluster name (must exist)"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version (must match/compatible with cluster)"
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs to place the nodes"
  type        = list(string)
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
  description = "Additional tags to be applied to all EKS node group resources"
  type        = map(string)
  default     = {}
}

variable "default_security_group_id" {
  description = "Security group automatically associated with managed node groups when no custom launch template is provided"
  type        = string
  default     = null
}

variable "nodegroups" {
  description = <<EOT
Map of node group configs. Example in README.
Fields:
  name                    (string, optional)
  capacity_type           (string)    — ON_DEMAND | SPOT
  instance_types          (list(string))
  ami_family              (string)    — AL2 | BOTTLEROCKET (sets ami_type automatically)
  ami_type_override       (string)    — optional explicit ami_type if you really need it
  disk_size               (number)    — GiB
  min_size                (number)
  max_size                (number)
  desired_size            (number, optional)
  update_max_unavailable  (number, optional)
  update_max_unavailable_percentage (number, optional)
  labels                  (map(string))
  taints                  (list(object({ key=string, value=optional(string), effect=string })))
  enable_ssm              (bool, default false)
  launch_template         (object({ id=string, version=string }))  — optional
  additional_policies_arns(list(string)) — attached to node role
  node_role_name_override (string)    — use existing role name instead of creating one
  remote_access           (object({
                              enabled=bool,
                              ec2_key_name=optional(string),
                              source_security_group_ids=optional(list(string), [])
                            }))
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
    taints                            = optional(list(object({ key = string, value = optional(string), effect = string })), [])
    enable_ssm                        = optional(bool, false)
    launch_template                   = optional(object({ id = string, version = string }))
    additional_policies_arns          = optional(list(string), [])
    node_role_name_override           = optional(string)
    remote_access = optional(object({
      enabled                   = bool,
      ec2_key_name              = optional(string)
      source_security_group_ids = optional(list(string), [])
    }), { enabled = false })
  }))
}