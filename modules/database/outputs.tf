output "db_endpoint" {
  description = "The endpoint of the RDS instance"
  value       = aws_db_instance.db.endpoint
}

output "db_address" {
  description = "The address of the RDS instance"
  value       = aws_db_instance.db.address
}

output "db_port" {
  description = "The port of the RDS instance"
  value       = aws_db_instance.db.port
}

output "db_secret_arn" {
  description = "ARN of the Secrets Manager secret containing database credentials"
  value       = aws_secretsmanager_secret.db_password.arn
}

output "db_secret_name" {
  description = "Name of the Secrets Manager secret"
  value       = aws_secretsmanager_secret.db_password.name
}