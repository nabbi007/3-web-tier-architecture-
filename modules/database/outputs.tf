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