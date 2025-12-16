variable "aws_region" {
  description = "AWS region"
  type        = string
  default = "eu-west-1"
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
  description = "illiasu is the owner"
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


variable "default_route_cidr" {
  description = "CIDR block for the default route"
  type        = string
  default     = "0.0.0.0/0"
}

