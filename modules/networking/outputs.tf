# VPC ID
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.nabs.id
}

# VPC CIDR
output "vpc_cidr" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.nabs.cidr_block
}

# NAT Gateway IDs
output "nat_gateway_ids" {
  description = "List of IDs of the NAT Gateways"
  value       = aws_nat_gateway.nat[*].id
}

# Public Subnet IDs
output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value       = aws_subnet.public[*].id
}

# App Private Subnet IDs
output "app_private_subnet_ids" {
  description = "List of IDs of private app subnets"
  value       = aws_subnet.app_private[*].id
}

# DB Private Subnet IDs
output "db_private_subnet_ids" {
  description = "List of IDs of private DB subnets"
  value       = aws_subnet.db_private[*].id
}

# Public Route Table (singleton)
output "public_route_table_id" {
  description = "ID of the public route table"
  value       = aws_route_table.public.id
}

# App Private Route Tables (counted)
output "app_private_route_table_ids" {
  description = "List of IDs of the app private route tables"
  value       = aws_route_table.app_private[*].id
}

# DB Private Route Table(s)
# Use this if you have one DB RT
output "db_private_route_table_id" {
  description = "ID of the DB private route table"
  value       = aws_route_table.db_private.id
}

# Use this instead if DB RT is counted per AZ
# output "db_private_route_table_ids" {
#   description = "List of IDs of the DB private route tables"
#   value       = aws_route_table.db_private[*].id
# }
