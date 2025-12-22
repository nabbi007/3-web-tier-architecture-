output "web_sg_id" {
  description = "The ID of the Web/ALB security group"
  value       = aws_security_group.web_alb_sg.id
}

output "app_sg_id" {
  description = "The ID of the App security group"
  value       = aws_security_group.app-sg.id
}

output "db_sg_id" {
  description = "The ID of the DB security group"
  value       = aws_security_group.db-sg.id
}
