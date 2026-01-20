variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "db_subnet_ids" {
  description = "List of DB subnet IDs"
  type        = list(string)
}

variable "db_sg_id" {
  description = "The ID of the DB security group"
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

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "mydb"
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "admin"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_engine" {
  description = "Database engine"
  type        = string
  default     = "mysql"
}

variable "db_engine_version" {
  description = "Database engine version"
  type        = string
  default     = "8.0"
}

variable "db_allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

variable "kms_key_id" {
  description = "KMS key ID for RDS encryption (leave empty to use AWS managed key)"
  type        = string
  default     = ""
}

variable "enable_multi_az" {
  description = "Enable Multi-AZ deployment for high availability"
  type        = bool
  default     = false  # Set to true for production
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for RDS instance"
  type        = bool
  default     = true  # Set to true for production
}
