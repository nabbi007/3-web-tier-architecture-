# 3-Tier Architecture Code Explanation

## Application Load Balancer (ALB) Module

### `modules/alb/main.tf`

```terraform
# Application Load Balancer
resource "aws_lb" "alb" {
  name               = "${var.project_name}-${var.environment}-alb"
  internal           = false  # Internet-facing ALB
  load_balancer_type = "application"
  security_groups    = [var.web_alb-sg_id]
  subnets            = var.public_subnet_ids
  
  # Enable deletion protection for production
  enable_deletion_protection = var.environment == "prod" ? true : false
  
  # Enable access logs for monitoring
  access_logs {
    bucket  = var.access_logs_bucket
    enabled = var.access_logs_bucket != "" ? true : false
  }
}

# Associate WAF with ALB for security
resource "aws_wafv2_web_acl_association" "main" {
  resource_arn = aws_lb.alb.arn
  web_acl_arn  = var.waf_web_acl_arn
}
```

**Purpose**: Creates an internet-facing Application Load Balancer that:
- Distributes incoming traffic across multiple EC2 instances
- Provides high availability and fault tolerance
- Integrates with WAF for security protection
- Logs access for monitoring and analysis

### Target Group Configuration

```terraform
# Target Group for App ASG
resource "aws_lb_target_group" "app" {
  name     = "${var.project_name}-${var.environment}-app-tg"
  port     = var.target_port  # Port 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = var.health_check_path  # "/health"
    interval            = 30    # Check every 30 seconds
    timeout             = 5     # 5 second timeout
    healthy_threshold   = 2     # 2 consecutive successes = healthy
    unhealthy_threshold = 5     # 5 consecutive failures = unhealthy
    matcher             = "200" # HTTP 200 response expected
  }
}
```

**Purpose**: Defines how the ALB routes traffic to EC2 instances:
- Health checks ensure only healthy instances receive traffic
- Optimized thresholds for faster detection and recovery
- Routes to application running on port 80

### HTTP/HTTPS Listeners

```terraform
# HTTP Listener - redirects to HTTPS if certificate exists
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"
  
  default_action {
    type = var.certificate_arn != "" ? "redirect" : "forward"
    
    # Redirect to HTTPS if SSL certificate is provided
    dynamic "redirect" {
      for_each = var.certificate_arn != "" ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
    
    # Forward to target group if no SSL certificate
    target_group_arn = var.certificate_arn == "" ? aws_lb_target_group.app.arn : null
  }
}

# HTTPS Listener - only created if certificate is provided
resource "aws_lb_listener" "https" {
  count             = var.certificate_arn != "" ? 1 : 0
  load_balancer_arn = aws_lb.alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
```

**Purpose**: Handles incoming requests:
- HTTP listener either forwards traffic or redirects to HTTPS
- HTTPS listener (optional) provides SSL termination
- Uses modern TLS 1.3 security policy

---

## Compute Module (EC2 Auto Scaling)

### `modules/compute/main.tf`

### IAM Role for EC2 Instances

```terraform
# IAM Role for EC2 instances
resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-${var.environment}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

# IAM Policy for Secrets Manager access
resource "aws_iam_role_policy" "secrets_manager_access" {
  name = "${var.project_name}-${var.environment}-secrets-access"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = var.db_secret_arn  # Only access to specific secret
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"  # Allow decryption of AWS managed keys
      }
    ]
  })
}
```

**Purpose**: Provides EC2 instances with necessary permissions:
- Allows instances to retrieve database credentials from Secrets Manager
- Enables KMS decryption for encrypted secrets
- Follows principle of least privilege

### Launch Template with Security Features

```terraform
# Launch Template
resource "aws_launch_template" "app" {
  name_prefix            = "${var.project_name}-${var.environment}-app-"
  image_id               = data.aws_ssm_parameter.ami.value
  instance_type          = var.instance_type
  vpc_security_group_ids = [var.app_sg_id]

  # Enforce IMDSv2 for security (prevents SSRF attacks)
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"  # Requires session tokens
    http_put_response_hop_limit = 1
  }

  # Encrypt EBS volumes
  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_type = "gp3"
      volume_size = 20
      encrypted   = true  # Encrypt storage at rest
      delete_on_termination = true
    }
  }

  iam_instance_profile {
    arn = aws_iam_instance_profile.ec2_profile.arn
  }

  user_data = base64encode(templatefile("${path.module}/../../scripts/user-data.sh", {
    GIT_REPO_URL    = var.git_repo_url
    GIT_BRANCH      = var.git_branch
    DB_SECRET_NAME  = var.db_secret_name
    AWS_REGION      = var.aws_region
  }))
}
```

**Purpose**: Defines the template for launching EC2 instances:
- Uses latest Ubuntu AMI from SSM Parameter Store
- Enforces IMDSv2 to prevent metadata service attacks
- Encrypts EBS volumes for data protection
- Passes configuration to user data script

### Auto Scaling Group

```terraform
# Auto Scaling Group
resource "aws_autoscaling_group" "app" {
  name                = "${var.project_name}-${var.environment}-app-asg"
  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.desired_capacity
  vpc_zone_identifier = var.private_subnet_ids
  health_check_type   = "ELB"  # Use ALB health checks
  health_check_grace_period = 900  # 15 minutes for app startup

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50  # Keep 50% instances during updates
      instance_warmup        = 600 # 10 minutes warmup time
    }
  }
}

# Attach ASG to Target Group
resource "aws_autoscaling_attachment" "app" {
  autoscaling_group_name = aws_autoscaling_group.app.id
  lb_target_group_arn    = var.target_group_arn
}
```

**Purpose**: Manages EC2 instances automatically:
- Maintains desired number of healthy instances
- Scales based on demand (can add scaling policies)
- Performs rolling updates without downtime
- Integrates with ALB target group for load balancing

---

## Database Module (RDS)

### `modules/database/main.tf`

### Secrets Manager for Database Credentials

```terraform
# Secrets Manager Secret - Auto-generated password
resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${var.project_name}-${var.environment}-db-credentials-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
  description             = "RDS database password for ${var.project_name}-${var.environment}"
  kms_key_id              = var.kms_key_id != "" ? var.kms_key_id : null
  recovery_window_in_days = 7  # 7-day recovery window
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
```

**Purpose**: Securely manages database credentials:
- Generates strong random passwords
- Stores credentials encrypted in Secrets Manager
- Includes all connection details in one secret
- Timestamp in name prevents conflicts with deleted secrets

### RDS Database Instance

```terraform
# RDS Instance
resource "aws_db_instance" "db" {
  identifier             = "db-${var.project_name}-${var.environment}"
  db_name                = var.db_name
  username               = var.db_username
  password               = random_password.db_password.result
  instance_class         = var.db_instance_class
  engine                 = var.db_engine
  engine_version         = var.db_engine_version
  allocated_storage      = var.db_allocated_storage
  db_subnet_group_name   = aws_db_subnet_group.db.name
  vpc_security_group_ids = [var.db_sg_id]
  publicly_accessible    = false  # Private database

  # Security features
  storage_encrypted = true
  kms_key_id        = var.kms_key_id != "" ? var.kms_key_id : null

  # Backup configuration
  backup_retention_period   = 7
  backup_window             = "03:00-04:00"
  maintenance_window        = "mon:04:00-mon:05:00"
  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]
  
  # Production settings
  deletion_protection = var.enable_deletion_protection
  skip_final_snapshot = true  # Set to false for production
}
```

**Purpose**: Creates a secure, managed MySQL database:
- Encrypted at rest and in transit
- Automated backups and maintenance
- CloudWatch logging for monitoring
- Isolated in private subnets

---

## Security Module

### `modules/security/main.tf`

### Security Groups

```terraform
# Web Security Group (for ALB)
resource "aws_security_group" "web_alb_sg" {
  name        = "${var.project_name}-${var.environment}-web-alb-sg"
  description = "Security group for ALB/Web"
  vpc_id      = var.vpc_id
}

# Allow HTTP from anywhere
resource "aws_vpc_security_group_ingress_rule" "web_http" {
  security_group_id = aws_security_group.web_alb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

# Allow HTTPS from anywhere
resource "aws_vpc_security_group_ingress_rule" "web_https" {
  security_group_id = aws_security_group.web_alb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

# App Security Group (for EC2)
resource "aws_security_group" "app-sg" {
  name        = "${var.project_name}-${var.environment}-app-sg"
  description = "App SG: Allow HTTP from ALB/Web SG"
  vpc_id      = var.vpc_id
}

# Allow HTTP from ALB only
resource "aws_vpc_security_group_ingress_rule" "app_http" {
  security_group_id            = aws_security_group.app-sg.id
  referenced_security_group_id = aws_security_group.web_alb_sg.id
  from_port                    = 80
  ip_protocol                  = "tcp"
  to_port                      = 80
}

# DB Security Group (for RDS)
resource "aws_security_group" "db-sg" {
  name        = "${var.project_name}-${var.environment}-db-sg"
  description = "DB SG: Allow DB port from App SG"
  vpc_id      = var.vpc_id
}

# Allow MySQL from App tier only
resource "aws_vpc_security_group_ingress_rule" "db_mysql" {
  security_group_id            = aws_security_group.db-sg.id
  referenced_security_group_id = aws_security_group.app-sg.id
  from_port                    = 3306
  ip_protocol                  = "tcp"
  to_port                      = 3306
}
```

**Purpose**: Implements defense-in-depth security:
- Web tier: Accepts HTTP/HTTPS from internet
- App tier: Only accepts traffic from ALB
- Database tier: Only accepts MySQL traffic from app tier
- No direct internet access to app or database tiers

### WAF Protection

```terraform
# WAF Web ACL for ALB protection
resource "aws_wafv2_web_acl" "main" {
  name  = "${var.project_name}-${var.environment}-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  # AWS Managed Rule - Core Rule Set
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1
    
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
  }

  # Rate limiting rule
  rule {
    name     = "RateLimitRule"
    priority = 3

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 2000  # Requests per 5 minutes
        aggregate_key_type = "IP"
      }
    }
  }
}
```

**Purpose**: Protects against web attacks:
- Blocks common attack patterns (SQL injection, XSS)
- Rate limiting prevents DDoS attacks
- Managed rules updated automatically by AWS

---

## User Data Script

### `scripts/user-data.sh`

```bash
#!/bin/bash
set -e

# Log everything to file
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "Starting user data script..."

# Update system and install dependencies
apt-get update -y
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs git jq

# Clone the application
cd /opt
git clone ${GIT_REPO_URL} kanban-app
cd /opt/kanban-app

# Checkout specific branch if specified
if [ -n "${GIT_BRANCH}" ]; then
  git checkout ${GIT_BRANCH}
fi

# Retrieve database credentials from Secrets Manager
SECRET_JSON=$(aws secretsmanager get-secret-value \
  --secret-id ${DB_SECRET_NAME} \
  --region ${AWS_REGION} \
  --query SecretString \
  --output text)

# Parse the secret JSON
DB_HOST=$(echo $${SECRET_JSON} | jq -r '.host')
DB_USER=$(echo $${SECRET_JSON} | jq -r '.username')
DB_PASSWORD=$(echo $${SECRET_JSON} | jq -r '.password')
DB_NAME=$(echo $${SECRET_JSON} | jq -r '.dbname')

# Create .env file with database credentials
cat > .env <<ENV
DB_HOST=$${DB_HOST}
DB_USER=$${DB_USER}
DB_PASSWORD=$${DB_PASSWORD}
DB_NAME=$${DB_NAME}
PORT=80
ENV

# Install dependencies and start application
npm install --production

# Create systemd service
cat > /etc/systemd/system/kanban-app.service <<'SERVICE'
[Unit]
Description=Kanban App
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/kanban-app
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICE

# Start and enable the service
systemctl daemon-reload
systemctl enable kanban-app
systemctl start kanban-app

echo "User data script completed successfully!"
```

**Purpose**: Automatically configures EC2 instances:
- Installs Node.js and dependencies
- Clones application from Git repository
- Retrieves database credentials securely from Secrets Manager
- Configures application as a systemd service
- Ensures application starts automatically on boot

---

## Architecture Flow

1. **Internet Traffic** → **ALB** (with WAF protection)
2. **ALB** → **Target Group** → **EC2 Instances** (in private subnets)
3. **EC2 Instances** → **RDS Database** (in private subnets)
4. **EC2 Instances** → **Secrets Manager** (for database credentials)

## Security Features

- **Network Isolation**: 3-tier security groups with least privilege access
- **Encryption**: EBS volumes, RDS storage, and Secrets Manager all encrypted
- **WAF Protection**: Blocks common web attacks and rate limits requests
- **IMDSv2**: Prevents metadata service attacks on EC2 instances
- **VPC Flow Logs**: Network traffic monitoring
- **No Direct Internet Access**: App and database tiers isolated from internet

## High Availability

- **Multi-AZ Deployment**: Resources spread across multiple availability zones
- **Auto Scaling**: Automatically replaces failed instances
- **Health Checks**: ALB only routes to healthy instances
- **Rolling Updates**: Zero-downtime deployments
- **Automated Backups**: RDS automated backups and point-in-time recovery