# VPC
resource "aws_vpc" "nabs" {
  cidr_block = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-vpc"
    Environment = var.environment
    Project     = var.project_name
    Owner       = var.owner
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.nabs.id

  tags = {
    Name        = "${var.project_name}-${var.environment}-igw"
    Environment = var.environment
    Project     = var.project_name
    Owner       = var.owner
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.nabs.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-public-${count.index + 1}"
    Environment = var.environment
    Project     = var.project_name
    Owner       = var.owner
    Type        = "public"
  }
}

# Private App Subnets
resource "aws_subnet" "app_private" {
  count             = length(var.app_private_subnet_cidrs)
  vpc_id            = aws_vpc.nabs.id
  cidr_block        = var.app_private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name        = "${var.project_name}-${var.environment}-app-private-subnet-${count.index + 1}"
    Environment = var.environment
    Project     = var.project_name
    Owner       = var.owner
    Type        = "private-app"
  }
}

# Private DB Subnets
resource "aws_subnet" "db_private" {
  count             = length(var.db_private_subnet_cidrs)
  vpc_id            = aws_vpc.nabs.id
  cidr_block        = var.db_private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name        = "${var.project_name}-${var.environment}-db-private-subnet-${count.index + 1}"
    Environment = var.environment
    Project     = var.project_name
    Owner       = var.owner
    Type        = "private-db"
  }
}

# EIP for NAT Gateway
resource "aws_eip" "nat" {
  count = length(var.availability_zones)
  domain = "vpc"

  tags = {
    Name        = "${var.project_name}-${var.environment}-nat-eip-${count.index + 1}"
    Environment = var.environment
    Project     = var.project_name
    Owner       = var.owner
  }
}

# NAT Gateway
resource "aws_nat_gateway" "nat" {
  count         = 1
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name        = "${var.project_name}-${var.environment}-nat-gw-${count.index + 1}"
    Environment = var.environment
    Project     = var.project_name
    Owner       = var.owner
  }
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.nabs.id

  route {
    cidr_block = var.default_route_cidr
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-public-rt"
    Environment = var.environment
    Project     = var.project_name
    Owner       = var.owner
  }
}

# Public Route Table Association
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private App Route Table
resource "aws_route_table" "app_private" {
  count = 2
  vpc_id = aws_vpc.nabs.id

  route {
    cidr_block     = var.default_route_cidr
    nat_gateway_id = aws_nat_gateway.nat[count.index].id
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-app-private-rt-${count.index + 1}"
    Environment = var.environment
    Project     = var.project_name
    Owner       = var.owner
  }
}

# Private App Route Table Association
resource "aws_route_table_association" "app_private" {
  count          = length(aws_subnet.app_private)
  subnet_id      = aws_subnet.app_private[count.index].id
  route_table_id = aws_route_table.app_private[count.index].id
}

# Private DB Route Table (no routes for internet)
resource "aws_route_table" "db_private" {
  vpc_id = aws_vpc.nabs.id

  tags = {
    Name        = "${var.project_name}-${var.environment}-db-private-rt"
    Environment = var.environment
    Project     = var.project_name
    Owner       = var.owner
  }
}

# Private DB Route Table Association
resource "aws_route_table_association" "db_private" {
  count          = length(aws_subnet.db_private)
  subnet_id      = aws_subnet.db_private[count.index].id
  route_table_id = aws_route_table.db_private.id
}
