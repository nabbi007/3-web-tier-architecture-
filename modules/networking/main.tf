
# VPC
resource "aws_vpc" "nabs" {
  cidr_block           = var.vpc_cidr
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
    Name        = "${var.project_name}-${var.environment}-app-private-${count.index + 1}"
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
    Name        = "${var.project_name}-${var.environment}-db-private-${count.index + 1}"
    Environment = var.environment
    Project     = var.project_name
    Owner       = var.owner
    Type        = "private-db"
  }
}


# Elastic IP (ONLY ONE)

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name        = "${var.project_name}-${var.environment}-nat-eip"
    Environment = var.environment
    Project     = var.project_name
    Owner       = var.owner
  }
}


# NAT Gateway (ONLY ONE)

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id   # NAT goes in FIRST public subnet

  tags = {
    Name        = "${var.project_name}-${var.environment}-nat-gw"
    Environment = var.environment
    Project     = var.project_name
    Owner       = var.owner
  }

  depends_on = [aws_internet_gateway.igw]
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


# Public Route Table Associations

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}


# App Private Route Table (USES SAME NAT)

resource "aws_route_table" "app_private" {
  vpc_id = aws_vpc.nabs.id

  route {
    cidr_block     = var.default_route_cidr
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-app-private-rt"
    Environment = var.environment
    Project     = var.project_name
    Owner       = var.owner
  }
}

# App Private Route Table Associations
resource "aws_route_table_association" "app_private" {
  count          = length(aws_subnet.app_private)
  subnet_id      = aws_subnet.app_private[count.index].id
  route_table_id = aws_route_table.app_private.id
}


# DB Private Route Table (NO INTERNET)
resource "aws_route_table" "db_private" {
  vpc_id = aws_vpc.nabs.id

  tags = {
    Name        = "${var.project_name}-${var.environment}-db-private-rt"
    Environment = var.environment
    Project     = var.project_name
    Owner       = var.owner
  }
}

# DB Route Table Associations
resource "aws_route_table_association" "db_private" {
  count          = length(aws_subnet.db_private)
  subnet_id      = aws_subnet.db_private[count.index].id
  route_table_id = aws_route_table.db_private.id
}
