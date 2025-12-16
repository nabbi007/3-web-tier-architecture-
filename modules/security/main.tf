# Web / ALB Security Group
resource "aws_security_group" "web_alb-sg" {
  name        = "${var.project_name}-${var.environment}-web-alb-sg"
  description = "Security group for ALB/Web"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from anywhere"
    from_port   = var.web_port
    to_port     = var.web_port
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

#   ingress {
#     description = "ICMP from anywhere"
#     from_port   = -1
#     to_port     = -1
#     protocol    = "icmp"
#     cidr_blocks = var.allowed_cidrs
#   }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = var.allowed_cidrs
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-web-alb-sg"
    Environment = var.environment
    Project     = var.project_name
    Owner       = var.owner
  }
}

# App (ASG EC2) Security Group
resource "aws_security_group" "app-sg" {
  name        = "${var.project_name}-${var.environment}-app-sg"
  description = "Security group for App EC2 instances in the private subnet"
  vpc_id      = var.vpc_id

# Only ALB can reach app on HTTP/HTTP
  ingress {
    description     = "HTTP from ALB SG"
    from_port       = var.web_port
    to_port         = var.web_port
    protocol        = "tcp"
    security_groups = [aws_security_group.web_alb-sg.id]
  }

  ingress {
    description = "SSH from anywhere"
    from_port   = var.ssh_port
    to_port     = var.ssh_port
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

  ingress {
    description     = "ICMP from ALB SG"
    from_port       = -1
    to_port         = -1
    protocol        = "icmp"
    security_groups = [aws_security_group.web_alb-sg.id]
  }

  ingress {
    description = "ICMP from VPC"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-app-sg"
    Environment = var.environment
    Project     = var.project_name
    Owner       = var.owner
  }
}

# DB Security Group
resource "aws_security_group" "db-sg" {
  name        = "${var.project_name}-${var.environment}-db-sg"
  description = "Security group for DB"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "${var.project_name}-${var.environment}-db-sg"
    Environment = var.environment
    Project     = var.project_name
    Owner       = var.owner
  }
}

# Security Group Rules to avoid cycles
resource "aws_security_group_rule" "app_to_db" {
  type                     = "egress"
  from_port                = var.db_port
  to_port                  = var.db_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.app-sg.id
  source_security_group_id = aws_security_group.db-sg.id
}

resource "aws_security_group_rule" "db_from_app" {
  type                     = "ingress"
  from_port                = var.db_port
  to_port                  = var.db_port
  protocol                 = "tcp"
  security_group_id        = aws_security_group.db-sg.id
  source_security_group_id = aws_security_group.app-sg.id
}
