variable "name_prefix" {
  description = "Prefix used for Name tags and resource names"
  type        = string
}

variable "project" { 
  type = string
  description = "Project tag" 
}

variable "environment" { 
  type = string
  description = "Environment tag"
}

variable "owner" { 
  type = string
  description = "Owner tag (email or team)"
}

variable "tags" { 
  type = map(string)
  default = {}
}

variable "eks_cluster_tags" {
  description = "Map of EKS cluster name => tag value ('owned' or 'shared') applied to public/private subnets"
  type        = map(string)
  default     = {}
}

variable "cidr_block" {
  description = "CIDR for the VPC (e.g. 10.0.0.0/16)"
  type        = string
}

variable "az_count" {
  description = "Number of AZs to use"
  type        = number
  default     = 3
}

variable "subnet_newbits" {
  description = "Number of newbits for subnet sizing (e.g. 4 gives /20s inside /16)"
  type        = number
  default     = 4
}

variable "nat_gateway_strategy" {
  description = "NAT strategy: 'one_per_az' (HA) or 'single' (cost-saver)"
  type        = string
  default     = "one_per_az"
  validation {
    condition     = contains(["one_per_az", "single"], var.nat_gateway_strategy)
    error_message = "nat_gateway_strategy must be 'one_per_az' or 'single'"
  }
}

variable "create_intra_subnets" {
  description = "Create intra (no egress) subnets"
  type        = bool
  default     = true
}

variable "create_database_subnets" {
  description = "Create database subnets"
  type        = bool
  default     = true
}

variable "enable_ipv6" {
  description = "Assign an IPv6 CIDR block to the VPC"
  type        = bool
  default     = false
}

# VPC Endpoints
variable "enable_s3_gateway_endpoint" {
  type        = bool
  default     = true
  description = "Create S3 Gateway endpoint and attach to route tables"
}

variable "enable_dynamodb_gateway_endpoint" {
  type        = bool
  default     = true
  description = "Create DynamoDB Gateway endpoint and attach to route tables"
}

variable "interface_endpoints" {
  description = "List of Interface endpoint service short names (e.g., ['ec2', 'ecr.api', 'ecr.dkr', 'logs', 'ssm', 'ssmmessages', 'ec2messages'])"
  type        = list(string)
  default     = ["ecr.api", "ecr.dkr", "logs", "ssm", "ssmmessages", "ec2messages"]
}

# Flow Logs
variable "flow_logs_destination_type" {
  description = "'s3' or 'cloudwatch'"
  type        = string
  default     = "s3"
  validation {
    condition     = contains(["s3", "cloudwatch"], var.flow_logs_destination_type)
    error_message = "flow_logs_destination_type must be 's3' or 'cloudwatch'"
  }
}

variable "flow_logs_s3_arn" {
  description = "S3 bucket ARN for flow logs (when destination is s3)"
  type        = string
  default     = null
}

variable "flow_logs_cw_retention_days" {
  description = "Retention in days for CloudWatch Logs (when used)"
  type        = number
  default     = 30
}

variable "flow_logs_kms_key_arn" {
  description = "KMS key ARN to encrypt CloudWatch Logs (optional) or S3 bucket policy can enforce SSE-KMS"
  type        = string
  default     = null
}