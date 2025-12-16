variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string

}

variable "vpc_cidr" {
  description = "The CIDR block of the VPC"
  type        = string
}

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

variable "db_port" {
  description = "Database port"
  type        = number
  default     = 3306
}

variable "web_port" {
  description = "Web port"
  type        = number
  default     = 80
}

variable "ssh_port" {
  description = "SSH port"
  type        = number
  default     = 22
}

variable "allowed_cidrs" {
  description = "Allowed CIDR blocks for public access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
