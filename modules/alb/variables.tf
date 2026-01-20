variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "web_alb-sg_id" {
  description = "The ID of the ALB security group"
  type        = string
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
}

variable "certificate_arn" {
  description = "ARN of the SSL certificate for HTTPS listener (optional)"
  type        = string
  default     = ""
}


variable "alb_port" {
  description = "ALB listener port"
  type        = number
  default     = 80
}

variable "target_port" {
  description = "group port"
  type        = number
  default     = 80
}

variable "health_check_path" {
  description = "Health check path"
  type        = string
  default     = "/health"
}
