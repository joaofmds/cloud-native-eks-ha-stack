output "vpc_id" {
  value       = aws_vpc.this.id
  description = "ID of the VPC created by this module"
}

output "vpc_cidr" {
  value       = var.cidr_block
  description = "CIDR block assigned to the VPC"
}

output "availability_zones" {
  value       = local.azs
  description = "Availability zones used to place the subnets"
}

output "public_subnet_ids" {
  value       = values(aws_subnet.public)[*].id
  description = "IDs of the public subnets"
}

output "public_subnet_cidrs" {
  value       = [for s in aws_subnet.public : s.cidr_block]
  description = "CIDR blocks allocated to the public subnets"
}

output "private_subnet_ids" {
  value       = values(aws_subnet.private)[*].id
  description = "IDs of the private subnets"
}

output "private_subnet_cidrs" {
  value       = [for s in aws_subnet.private : s.cidr_block]
  description = "CIDR blocks allocated to the private subnets"
}

output "intra_subnet_ids" {
  value       = values(aws_subnet.intra)[*].id
  description = "Empty if create_intra_subnets=false"
}

output "database_subnet_ids" {
  value       = values(aws_subnet.database)[*].id
  description = "Empty if create_database_subnets=false"
}

output "public_route_table_id" {
  value       = aws_route_table.public.id
  description = "Route table associated with the public subnets"
}

output "private_route_table_ids" {
  value       = values(aws_route_table.private)[*].id
  description = "Route tables associated with the private subnets"
}

output "nat_gateway_ids" {
  value       = values(aws_nat_gateway.this)[*].id
  description = "IDs of the NAT gateways created for this VPC"
}

output "s3_gateway_endpoint_id" {
  value       = try(aws_vpc_endpoint.s3[0].id, null)
  description = "null if disabled"
}

output "dynamodb_gateway_endpoint_id" {
  value       = try(aws_vpc_endpoint.dynamodb[0].id, null)
  description = "null if disabled"
}

output "interface_endpoint_ids" {
  value       = [for k, v in aws_vpc_endpoint.interface : v.id]
  description = "IDs of the interface VPC endpoints"
}
