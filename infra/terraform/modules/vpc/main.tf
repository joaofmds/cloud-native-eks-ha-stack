data "aws_caller_identity" "this" {}

data "aws_region" "this" {}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  name_prefix = var.name_prefix
  azs         = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  public_subnet_indexes   = [for i in range(length(local.azs)) : i]
  private_subnet_indexes  = [for i in range(length(local.azs)) : i + 100]
  intra_subnet_indexes    = [for i in range(length(local.azs)) : i + 200]
  database_subnet_indexes = [for i in range(length(local.azs)) : i + 300]

  public_subnet_cidrs = [
    for i in local.public_subnet_indexes :
    cidrsubnet(var.cidr_block, var.subnet_newbits, i)
  ]

  private_subnet_cidrs = [
    for i in local.private_subnet_indexes :
    cidrsubnet(var.cidr_block, var.subnet_newbits, i)
  ]

  intra_subnet_cidrs = var.create_intra_subnets ? [
    for i in local.intra_subnet_indexes :
    cidrsubnet(var.cidr_block, var.subnet_newbits, i)
  ] : []

  database_subnet_cidrs = var.create_database_subnets ? [
    for i in local.database_subnet_indexes :
    cidrsubnet(var.cidr_block, var.subnet_newbits, i)
  ] : []

  eks_cluster_tags = { for cluster_name, value in var.eks_cluster_tags : "kubernetes.io/cluster/${cluster_name}" => value }

  public_subnet_extra_tags = length(local.eks_cluster_tags) > 0 ? merge(
    {
      "kubernetes.io/role/elb" = "1"
    },
    local.eks_cluster_tags,
  ) : {}

  private_subnet_extra_tags = length(local.eks_cluster_tags) > 0 ? merge(
    {
      "kubernetes.io/role/internal-elb" = "1"
    },
    local.eks_cluster_tags,
  ) : {}
  
  common_tags = merge({
    "ManagedBy"   = "Terraform",
    "Project"     = var.project,
    "Environment" = var.environment,
    "Owner"       = var.owner,
  }, var.tags)
}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  assign_generated_ipv6_cidr_block = var.enable_ipv6

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc"
  })
}

resource "aws_vpc_ipv6_cidr_block_association" "this" {
  count      = var.enable_ipv6 ? 1 : 0
  vpc_id     = aws_vpc.this.id
  ipv6_ipam_pool_id = null
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.common_tags, { Name = "${local.name_prefix}-igw" })
}

# ── PUBLIC SUBNETS & ROUTES ───────────────────────────────────────────────────
resource "aws_subnet" "public" {
  for_each = { for idx, az in local.azs : idx => {
    az   = az
    cidr = local.public_subnet_cidrs[idx]
  } }

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-${each.value.az}",
    Tier = "public"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = merge(local.common_tags, { Name = "${local.name_prefix}-rtb-public" })
}

resource "aws_route" "public_inet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# ── PRIVATE SUBNETS & NAT GATEWAYS ────────────────────────────────────────────
resource "aws_eip" "nat" {
  for_each = var.nat_gateway_strategy == "one_per_az" ? aws_subnet.public : {
    single = values(aws_subnet.public)[0]
  }

  domain = "vpc"
  tags   = merge(local.common_tags, { Name = "${local.name_prefix}-eip-nat-${each.key}" })
}

resource "aws_nat_gateway" "this" {
  for_each = aws_eip.nat

  allocation_id = each.value.id
  subnet_id     = var.nat_gateway_strategy == "one_per_az" ? aws_subnet.public[each.key].id : values(aws_subnet.public)[0].id

  depends_on = [aws_internet_gateway.this]
  tags       = merge(local.common_tags, { Name = "${local.name_prefix}-nat-${each.key}" })
}

resource "aws_subnet" "private" {
  for_each = { for idx, az in local.azs : idx => {
    az   = az
    cidr = local.private_subnet_cidrs[idx]
  } }

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-private-${each.value.az}",
    Tier = "private"
  })
}

resource "aws_route_table" "private" {
  for_each = aws_subnet.private
  vpc_id   = aws_vpc.this.id
  tags     = merge(local.common_tags, { Name = "${local.name_prefix}-rtb-private-${each.key}" })
}

resource "aws_route" "private_default" {
  for_each = aws_route_table.private

  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.nat_gateway_strategy == "one_per_az" ? aws_nat_gateway.this[each.key].id : aws_nat_gateway.this["single"].id
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

# ── INTRA SUBNETS (no egress to Internet; internal load balancers, etc.) ─────
resource "aws_subnet" "intra" {
  for_each = var.create_intra_subnets ? { for idx, az in local.azs : idx => {
    az   = az
    cidr = local.intra_subnet_cidrs[idx]
  } } : {}

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-intra-${each.value.az}",
    Tier = "intra"
  })
}

resource "aws_route_table" "intra" {
  for_each = aws_subnet.intra
  vpc_id   = aws_vpc.this.id
  tags     = merge(local.common_tags, { Name = "${local.name_prefix}-rtb-intra-${each.key}" })
}

resource "aws_route_table_association" "intra" {
  for_each       = aws_subnet.intra
  subnet_id      = each.value.id
  route_table_id = aws_route_table.intra[each.key].id
}

# ── DATABASE SUBNETS (no direct Internet) ─────────────────────────────────────
resource "aws_subnet" "database" {
  for_each = var.create_database_subnets ? { for idx, az in local.azs : idx => {
    az   = az
    cidr = local.database_subnet_cidrs[idx]
  } } : {}

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-db-${each.value.az}",
    Tier = "database"
  })
}

resource "aws_route_table" "database" {
  for_each = aws_subnet.database
  vpc_id   = aws_vpc.this.id
  tags     = merge(local.common_tags, { Name = "${local.name_prefix}-rtb-db-${each.key}" })
}

resource "aws_route_table_association" "database" {
  for_each       = aws_subnet.database
  subnet_id      = each.value.id
  route_table_id = aws_route_table.database[each.key].id
}

# ── VPC Endpoints ─────────────────────────────────────────────────────────────
resource "aws_vpc_endpoint" "s3" {
  count             = var.enable_s3_gateway_endpoint ? 1 : 0
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.this.id}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat(
    [aws_route_table.public.id],
    values(aws_route_table.private)[*].id,
    values(aws_route_table.intra)[*].id,
    values(aws_route_table.database)[*].id,
  )
  tags = merge(local.common_tags, { Name = "${local.name_prefix}-vpce-s3" })
}

resource "aws_vpc_endpoint" "dynamodb" {
  count             = var.enable_dynamodb_gateway_endpoint ? 1 : 0
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.this.id}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat(
    [aws_route_table.public.id],
    values(aws_route_table.private)[*].id,
    values(aws_route_table.intra)[*].id,
    values(aws_route_table.database)[*].id,
  )
  tags = merge(local.common_tags, { Name = "${local.name_prefix}-vpce-dynamodb" })
}

resource "aws_security_group" "vpce" {
  count  = length(var.interface_endpoints) > 0 ? 1 : 0
  name   = "${local.name_prefix}-vpce"
  vpc_id = aws_vpc.this.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-vpce" })
}

resource "aws_vpc_endpoint" "interface" {
  for_each          = toset(var.interface_endpoints)
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.this.id}.${each.value}"
  vpc_endpoint_type = "Interface"
  private_dns_enabled = true
  subnet_ids        = values(aws_subnet.private)[*].id
  security_group_ids = length(var.interface_endpoints) > 0 ? [aws_security_group.vpce[0].id] : []
  tags = merge(local.common_tags, { Name = "${local.name_prefix}-vpce-${each.value}" })
}

# ── Flow Logs ─────────────────────────────────────────────────────────────────
resource "aws_iam_role" "flowlogs" {
  count = var.flow_logs_destination_type == "cloudwatch" ? 1 : 0
  name  = "${local.name_prefix}-vpc-flowlogs-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
    }]
  })
  tags = local.common_tags
}

resource "aws_iam_role_policy" "flowlogs" {
  count = var.flow_logs_destination_type == "cloudwatch" ? 1 : 0
  name  = "${local.name_prefix}-vpc-flowlogs-policy"
  role  = aws_iam_role.flowlogs[0].id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogGroups", "logs:DescribeLogStreams"],
      Resource = "*"
    }]
  })
}

resource "aws_cloudwatch_log_group" "flowlogs" {
  count             = var.flow_logs_destination_type == "cloudwatch" ? 1 : 0
  name              = "/vpc/${local.name_prefix}/flow-logs"
  retention_in_days = var.flow_logs_cw_retention_days
  kms_key_id        = var.flow_logs_kms_key_arn != null ? var.flow_logs_kms_key_arn : null
  tags              = local.common_tags
}

resource "aws_flow_log" "this" {
  log_destination_type = var.flow_logs_destination_type
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.this.id

  log_destination = var.flow_logs_destination_type == "s3" ? var.flow_logs_s3_arn : (var.flow_logs_destination_type == "cloudwatch" ? aws_cloudwatch_log_group.flowlogs[0].arn : null)
  iam_role_arn    = var.flow_logs_destination_type == "cloudwatch" ? aws_iam_role.flowlogs[0].arn : null

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-vpc-flowlogs" })
}
