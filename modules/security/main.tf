
# Web Security Group (for ALB/public)
resource "aws_security_group" "web_alb_sg" {
  name        = "${var.project_name}-${var.environment}-web-alb-sg"
  description = "Security group for ALB/Web"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "${var.project_name}-${var.environment}-web-alb-sg"
    Environment = var.environment
    Project     = var.project_name
    Owner       = var.owner
  }
}

# Allow HTTP from anywhere
resource "aws_vpc_security_group_ingress_rule" "web_http" {
  security_group_id = aws_security_group.web_alb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}
# Allow ICMP (ping) from anywhere
resource "aws_vpc_security_group_ingress_rule" "web_icmp" {
  security_group_id = aws_security_group.web_alb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = -1
  ip_protocol       = "icmp"
  to_port           = -1
}
# Allow all outbound
resource "aws_vpc_security_group_egress_rule" "web_all" {
  security_group_id = aws_security_group.web_alb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# App Security Group (for EC2/app tier)
resource "aws_security_group" "app-sg" {
  name        = "${var.project_name}-${var.environment}-app-sg"
  description = "App SG: Allow HTTP from ALB/Web SG, ICMP from Web SG, all egress"
  vpc_id      = var.vpc_id
    tags = {
    Name        = "${var.project_name}-${var.environment}-web-alb-sg"
    Environment = var.environment
    Project     = var.project_name
    Owner       = var.owner
  }
}
# Allow HTTP from Web SG
resource "aws_vpc_security_group_ingress_rule" "app_http" {
  security_group_id            = aws_security_group.app-sg.id
  referenced_security_group_id = aws_security_group.web_alb_sg.id
  from_port                    = 80
  ip_protocol                  = "tcp"
  to_port                      = 80
}
# Allow ICMP from Web SG
resource "aws_vpc_security_group_ingress_rule" "app_icmp" {
  security_group_id            = aws_security_group.app-sg.id
  referenced_security_group_id = aws_security_group.web_alb_sg.id
  from_port                    = -1
  ip_protocol                  = "icmp"
  to_port                      = -1
}
# Allow all outbound
resource "aws_vpc_security_group_egress_rule" "app_all" {
  security_group_id = aws_security_group.app-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# DB Security Group (for RDS)
resource "aws_security_group" "db-sg" {
  name        = "${var.project_name}-${var.environment}-db-sg"
  description = "DB SG: Allow DB port from App SG, ICMP from App SG, all egress"
  vpc_id      = var.vpc_id

 tags = {
    Name        = "${var.project_name}-${var.environment}-db-sg"
    Environment = var.environment
    Project     = var.project_name
    Owner       = var.owner
  }
}
# Allow DB port (MySQL 3306) from App SG
resource "aws_vpc_security_group_ingress_rule" "db_mysql" {
  security_group_id            = aws_security_group.db-sg.id
  referenced_security_group_id = aws_security_group.app-sg.id
  from_port                    = 3306
  ip_protocol                  = "tcp"
  to_port                      = 3306
}
# Allow ICMP from App SG
resource "aws_vpc_security_group_ingress_rule" "db_icmp" {
  security_group_id            = aws_security_group.db-sg.id
  referenced_security_group_id = aws_security_group.app-sg.id
  from_port                    = -1
  ip_protocol                  = "icmp"
  to_port                      = -1
}
# Allow all outbound
resource "aws_vpc_security_group_egress_rule" "db_all" {
  security_group_id = aws_security_group.db-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
