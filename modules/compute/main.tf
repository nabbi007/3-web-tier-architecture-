data "aws_ssm_parameter" "ami" {
  name = var.ami_ssm_parameter_name
}

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

  tags = {
    Name        = "${var.project_name}-${var.environment}-ec2-role"
    Environment = var.environment
    Project     = var.project_name
    Owner       = var.owner
  }
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
        Resource = var.db_secret_arn
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"  # Allow decryption of AWS managed keys
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Policy for Systems Manager (SSM) Session Manager - Secure EC2 access without SSH
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-${var.environment}-ec2-profile"
  role = aws_iam_role.ec2_role.name

  tags = {
    Name        = "${var.project_name}-${var.environment}-ec2-profile"
    Environment = var.environment
    Project     = var.project_name
    Owner       = var.owner
  }
}

# Launch Template
resource "aws_launch_template" "app" {
  name_prefix            = "${var.project_name}-${var.environment}-app-"
  image_id               = data.aws_ssm_parameter.ami.value
  instance_type          = var.instance_type
  vpc_security_group_ids = [var.app_sg_id]

  iam_instance_profile {
    arn = aws_iam_instance_profile.ec2_profile.arn
  }

  user_data = base64encode(<<-EOF
#!/bin/bash
apt-get update -y
apt-get install -y nodejs npm git awscli jq

# Clone the application from GitHub
git clone ${var.git_repo_url} /opt/kanban-app
cd /opt/kanban-app

# Install dependencies
npm install

# Fetch secrets from AWS Secrets Manager
SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id ${var.db_secret_name} --region ${var.aws_region} --query SecretString --output text)
DB_USERNAME=$(echo $SECRET_JSON | jq -r '.username')
DB_PASSWORD=$(echo $SECRET_JSON | jq -r '.password')

# Set environment variables for the app
cat > /etc/environment <<ENV
DB_HOST=${var.db_endpoint}
DB_USER=$DB_USERNAME
DB_PASSWORD=$DB_PASSWORD
DB_NAME=${var.db_name}
PORT=80
ENV

cat > /etc/systemd/system/kanban-app.service <<'SVC'
[Unit]
Description=Kanban App
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/kanban-app
EnvironmentFile=/etc/environment
ExecStart=/usr/bin/node server.js
Restart=always

[Install]
WantedBy=multi-user.target
SVC

systemctl daemon-reload
systemctl enable kanban-app
systemctl start kanban-app
EOF
  )

  tags = {
    Name        = "${var.project_name}-${var.environment}-app"
    Environment = var.environment
    Project     = var.project_name
    Owner       = var.owner
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "app" {
  name                = "${var.project_name}-${var.environment}-app-asg"
  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.desired_capacity
  vpc_zone_identifier = var.private_subnet_ids
  health_check_type   = "ELB"
  health_check_grace_period = 600  # 10 minutes - allow time for app deployment

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 600
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-${var.environment}-app"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = var.project_name
    propagate_at_launch = true
  }

  tag {
    key                 = "Owner"
    value               = var.owner
    propagate_at_launch = true
  }
}

# Attach ASG to Target Group
resource "aws_autoscaling_attachment" "app" {
  autoscaling_group_name = aws_autoscaling_group.app.id
  lb_target_group_arn    = var.target_group_arn
}
