output "alb_dns" {
  value = module.alb.alb_dns
}

output "asg_name" {
  value = module.compute.asg_name
}

output "rds_endpoint" {
  value = module.database.db_endpoint
}
