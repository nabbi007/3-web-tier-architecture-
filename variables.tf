variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "3-web-project-Iac"
  type        = string
  default     = "3tier"
}

variable "owner" {
  description = "illiasu"
  type        = string
  default     = "illiasu"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "app_private_subnet_cidrs" {
  description = "CIDR blocks for private app subnets"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "db_private_subnet_cidrs" {
  description = "CIDR blocks for private db subnets"
  type        = list(string)
  default     = ["10.0.5.0/24", "10.0.6.0/24"]
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b"]
}

variable "db_port" {
  description = "Database port"
  type        = number
  default     = 3306
}


variable "ami_ssm_parameter_name" {
  type        = string
  description = "SSM parameter name that holds the AMI ID"
  default     = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64"
}


variable "instance_type" {
  type        = string
  description = "EC2 instance type for the app ASG"
  default     = "t3.micro"
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "kanbandb"
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
  default     = "ChangeMe123!"
}

variable "app_repo_url" {
  description = "Git repository URL for the Kanban application"
  type        = string
  default     = "https://github.com/nabbi007/Kanban-app.git"
}

variable "app_version" {
  description = "Application version to trigger instance refresh (e.g., commit hash or version number)"
  type        = string
  default     = "v1.0.0"
}
