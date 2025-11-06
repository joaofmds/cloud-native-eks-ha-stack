variable "enable_versioning" {
  description = "Ativar versionamento no bucket S3"
  type        = bool
  default     = true
}

variable "logging_bucket" {
  description = "Nome do bucket para armazenar logs de acesso"
  type        = string
}

variable "environment" {
  description = "Ambiente de implantação"
  type        = string
}

variable "project_name" {
  type        = string
  description = "Nome do projeto para prefixar recursos."
}

variable "owner" {
  description = "Time responsável pelo recurso"
  type        = string
}

variable "application" {
  description = "Aplicação que utiliza o recurso"
  type        = string
}

variable "tags" {
  type = map(string)
  default = {
    ManagedBy = "Terraform"
  }
  description = "Tags padrão aplicadas aos recursos"
}

variable "region" {
  description = "Região AWS"
  type        = string
}