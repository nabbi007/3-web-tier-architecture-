# DB Subnet Group
resource "aws_db_subnet_group" "db" {
  name = "a${var.project_name}-${var.environment}-db-subnet-group"
  subnet_ids = var.db_subnet_ids

  tags = {
    Name        = "${var.project_name}-${var.environment}-db-subnet-group"
    Environment = var.environment
    Project     = var.project_name
    Owner       = var.owner
  }
}

# Secrets Manager Secret - Auto-generated password
resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${var.project_name}-${var.environment}-db-credentials-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  description             = "RDS database password for ${var.project_name}-${var.environment}"
  kms_key_id              = var.kms_key_id != "" ? var.kms_key_id : null
  # recovery_window_in_days = 7  # 7-day recovery window before permanent deletion
  
  tags = {
    Name        = "${var.project_name}-${var.environment}-db-password"
    Environment = var.environment
    Project     = var.project_name
    Owner       = var.owner
  }
}

# Generate random password and store in Secrets Manager
resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id = aws_secretsmanager_secret.db_password.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password.result
    engine   = var.db_engine
    host     = aws_db_instance.db.address
    port     = aws_db_instance.db.port
    dbname   = var.db_name
  })
}

# Generate random password
resource "random_password" "db_password" {
  length  = 32
  special = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
  
}

# RDS Instance
resource "aws_db_instance" "db" {
  identifier             = "db-${var.project_name}-${var.environment}"
  db_name                = var.db_name
  username               = var.db_username
  password               = random_password.db_password.result  # Auto-generated password
  instance_class         = var.db_instance_class
  engine                 = var.db_engine
  engine_version         = var.db_engine_version
  allocated_storage      = var.db_allocated_storage
  db_subnet_group_name   = aws_db_subnet_group.db.name
  vpc_security_group_ids = [var.db_sg_id]
  publicly_accessible    = false
  skip_final_snapshot    = true

  # Encryption at rest
  storage_encrypted = true
  kms_key_id        = var.kms_key_id != "" ? var.kms_key_id : null  # Uses default AWS managed key if not specified

  # Backup configuration
  backup_retention_period   = 7                    # Keep backups for 7 days
  backup_window             = "03:00-04:00"        # Backup between 3-4 AM UTC
  maintenance_window        = "mon:04:00-mon:05:00" # Maintenance window
  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]  # CloudWatch logs
  
  # High availability
  multi_az = var.enable_multi_az  # Multi-AZ deployment for production

  # Performance Insights (requires db.t3.small or larger)
  # performance_insights_enabled    = true
  # performance_insights_retention_period = 7

  # Deletion protection (enable in production)
  deletion_protection = false

  tags = {
    Name        = "${var.project_name}-${var.environment}-db"
    Environment = var.environment
    Project     = var.project_name
    Owner       = var.owner
  }
}
