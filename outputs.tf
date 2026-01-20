output "alb_dns" {
  value = module.alb.alb_dns
}

output "asg_name" {
  value = module.compute.asg_name
}

output "rds_endpoint" {
  value = module.database.db_endpoint
}

output "db_secret_name" {
  description = "Name of the Secrets Manager secret containing database credentials"
  value       = module.database.db_secret_name
}

output "db_secret_arn" {
  description = "ARN of the Secrets Manager secret"
  value       = module.database.db_secret_arn
  sensitive   = true
}
