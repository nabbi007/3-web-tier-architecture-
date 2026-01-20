variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for app"
  type        = list(string)
}

variable "app_sg_id" {
  description = "The ID of the app security group"
  type        = string
}

variable "target_group_arn" {
  description = "The ARN of the target group"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "owner" {
  description = "Owner of the resources"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "min_size" {
  description = "Minimum number of instances in ASG"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of instances in ASG"
  type        = number
  default     = 3
}

variable "desired_capacity" {
  description = "Desired number of instances in ASG"
  type        = number
  default     = 2
}


variable "ami_ssm_parameter_name" {
  type        = string
  description = "SSM parameter name that holds the AMI ID"
}
variable "ami_owner" {
  type        = string
  description = "Owner ID for the AMI filter"
  default     = "099720109477" # Canonical
}

variable "db_secret_arn" {
  description = "ARN of the Secrets Manager secret containing database credentials"
  type        = string
}

variable "db_secret_name" {
  description = "Name of the Secrets Manager secret"
  type        = string
}

variable "db_endpoint" {
  description = "RDS database endpoint"
  type        = string
}

variable "db_name" {
  description = "Database name"
  type        = string
}

variable "aws_region" {
  description = "AWS region for Secrets Manager access"
  type        = string
}

variable "git_repo_url" {
  description = "Git repository URL for the kanban application"
  type        = string
}

variable "git_branch" {
  description = "Git branch to checkout (optional, defaults to repo default branch)"
  type        = string
  default     = ""
}