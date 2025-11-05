locals {
  name_prefix = "${var.project}-${var.environment}"

  private_zone_associations = var.route53_create_private_zone ? concat(
    [
      {
        vpc_id     = module.vpc.vpc_id
        vpc_region = var.aws_region
      }
    ],
    var.route53_additional_private_zone_associations,
  ) : []
}

module "s3_loki" {
  source = "../../modules/s3-loki"

  name_prefix = local.name_prefix
  project     = var.project
  environment = var.environment
  owner       = var.owner
  tags        = var.tags

  bucket_name   = var.s3_loki_bucket_name
  versioning    = var.s3_loki_enable_versioning
  force_destroy = var.s3_loki_force_destroy
  kms_key_arn   = var.s3_loki_kms_key_arn
}

module "s3_tempo" {
  source = "../../modules/s3-tempo"

  name_prefix = local.name_prefix
  project     = var.project
  environment = var.environment
  owner       = var.owner
  tags        = var.tags

  bucket_name    = var.s3_tempo_bucket_name
  versioning     = var.s3_tempo_enable_versioning
  force_destroy  = var.s3_tempo_force_destroy
  kms_key_arn    = var.s3_tempo_kms_key_arn
  retention_days = var.s3_tempo_retention_days
}

module "vpc" {
  source = "../../modules/vpc"

  name_prefix = local.name_prefix
  project     = var.project
  environment = var.environment
  owner       = var.owner
  tags        = var.tags

  cidr_block                       = var.vpc_cidr_block
  az_count                         = var.vpc_az_count
  subnet_newbits                   = var.vpc_subnet_newbits
  nat_gateway_strategy             = var.vpc_nat_gateway_strategy
  create_intra_subnets             = var.vpc_create_intra_subnets
  create_database_subnets          = var.vpc_create_database_subnets
  enable_ipv6                      = var.vpc_enable_ipv6
  enable_s3_gateway_endpoint       = var.vpc_enable_s3_gateway_endpoint
  enable_dynamodb_gateway_endpoint = var.vpc_enable_dynamodb_gateway_endpoint
  interface_endpoints              = var.vpc_interface_endpoints
  flow_logs_destination_type       = var.vpc_flow_logs_destination_type
  flow_logs_s3_arn                 = var.vpc_flow_logs_s3_arn
  flow_logs_cw_retention_days      = var.vpc_flow_logs_cw_retention_days
  flow_logs_kms_key_arn            = var.vpc_flow_logs_kms_key_arn
}

module "eks" {
  source = "../../modules/eks"

  cluster_name    = var.eks_cluster_name
  cluster_version = var.eks_cluster_version

  project     = var.project
  environment = var.environment
  owner       = var.owner
  tags        = var.tags

  vpc_id                    = module.vpc.vpc_id
  vpc_cidr_block            = module.vpc.vpc_cidr_block
  public_subnet_cidr_blocks = module.vpc.public_subnet_cidrs
  cluster_subnet_ids        = module.vpc.private_subnet_ids
  nodegroup_subnet_ids      = module.vpc.private_subnet_ids

  endpoint_public_access       = var.eks_endpoint_public_access
  endpoint_public_access_cidrs = var.eks_endpoint_public_access_cidrs
  endpoint_private_access      = var.eks_endpoint_private_access

  cluster_log_types                 = var.eks_cluster_log_types
  secrets_kms_key_arn               = var.eks_secrets_kms_key_arn
  security_group_additional_ingress = var.eks_security_group_additional_ingress

  enable_core_addons = var.eks_enable_core_addons

  eks_admin_principal_arns = var.eks_admin_principal_arns
  eks_view_principal_arns  = var.eks_view_principal_arns

  enable_nodegroups = var.eks_enable_nodegroups
  nodegroups        = var.eks_nodegroups
}

module "route53" {
  source = "../../modules/route53"

  zone_name   = var.route53_zone_name
  project     = var.project
  environment = var.environment
  owner       = var.owner
  tags        = var.tags

  create_public_zone      = var.route53_create_public_zone
  existing_public_zone_id = var.route53_existing_public_zone_id
  create_private_zone     = var.route53_create_private_zone

  private_zone_vpc_associations = local.private_zone_associations

  enable_dnssec        = var.route53_enable_dnssec
  enable_query_logging = var.route53_enable_query_logging
}

module "iam" {
  source = "../../modules/iam"

  project     = var.project
  environment = var.environment
  owner       = var.owner
  tags        = var.tags

  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_issuer_url   = module.eks.oidc_provider_url

  generic_irsa_roles = var.iam_generic_irsa_roles

  enable_external_dns = var.iam_enable_external_dns
  external_dns = {
    namespace       = var.iam_external_dns_namespace
    service_account = var.iam_external_dns_service_account
    zone_ids        = var.iam_external_dns_zone_ids
  }

  enable_cert_manager = var.iam_enable_cert_manager
  cert_manager = {
    namespace       = var.iam_cert_manager_namespace
    service_account = var.iam_cert_manager_service_account
    zone_ids        = var.iam_cert_manager_zone_ids
  }

  enable_cluster_autoscaler = var.iam_enable_cluster_autoscaler
  cluster_autoscaler = {
    namespace       = var.iam_cluster_autoscaler_namespace
    service_account = var.iam_cluster_autoscaler_service_account
  }

  enable_aws_load_balancer_controller = var.iam_enable_load_balancer_controller
  aws_load_balancer_controller = {
    namespace       = var.iam_load_balancer_controller_namespace
    service_account = var.iam_load_balancer_controller_service_account
  }

  enable_loki_s3 = var.iam_enable_loki_s3
  loki_s3 = var.iam_enable_loki_s3 ? {
    namespace        = var.iam_loki_namespace
    service_accounts = var.iam_loki_service_accounts
    bucket_arn       = module.s3_loki.bucket_arn
  } : null

  enable_tempo_s3 = var.iam_enable_tempo_s3
  tempo_s3 = var.iam_enable_tempo_s3 ? {
    namespace        = var.iam_tempo_namespace
    service_accounts = var.iam_tempo_service_accounts
    bucket_arn       = module.s3_tempo.bucket_arn
  } : null

  enable_otel_xray = var.iam_enable_otel_xray
  otel_xray = var.iam_enable_otel_xray ? {
    namespace       = var.iam_otel_namespace
    service_account = var.iam_otel_service_account
  } : null

  enable_ebs_csi_driver = var.iam_enable_ebs_csi_driver
  ebs_csi_driver = var.iam_enable_ebs_csi_driver ? {
    namespace       = var.iam_ebs_csi_driver_namespace
    service_account = var.iam_ebs_csi_driver_service_account
  } : null
}

resource "aws_eks_addon" "ebs_csi_driver" {
  count = var.eks_enable_ebs_csi_driver ? 1 : 0

  cluster_name = module.eks.cluster_name
  addon_name   = "aws-ebs-csi-driver"

  addon_version               = var.eks_ebs_csi_driver_version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  service_account_role_arn    = module.iam.ebs_csi_driver_role_arn

  depends_on = [module.iam]

  lifecycle {
    precondition {
      condition     = module.iam.ebs_csi_driver_role_arn != null
      error_message = "aws_eks_addon.ebs_csi_driver requires iam_enable_ebs_csi_driver to be true so that the service account role ARN is available."
    }
  }
}
