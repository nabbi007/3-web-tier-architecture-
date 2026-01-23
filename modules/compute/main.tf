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

  user_data = base64encode(templatefile("${path.module}/../../scripts/user-data.sh", {
    GIT_REPO_URL    = var.git_repo_url
    GIT_BRANCH      = var.git_branch
    DB_SECRET_NAME  = var.db_secret_name
    AWS_REGION      = var.aws_region
    DB_ENDPOINT     = var.db_endpoint
  }))

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
  health_check_grace_period = 600  # 10 minutes - allow time for app deployment and DB initialization

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

# # Scale Up Policy
# resource "aws_autoscaling_policy" "scale_up" {
#   name                   = "${var.project_name}-${var.environment}-scale-up"
#   scaling_adjustment     = 1
#   adjustment_type        = "ChangeInCapacity"
#   cooldown              = 300
#   autoscaling_group_name = aws_autoscaling_group.app.name
# }

# # Scale Down Policy
# resource "aws_autoscaling_policy" "scale_down" {
#   name                   = "${var.project_name}-${var.environment}-scale-down"
#   scaling_adjustment     = -1
#   adjustment_type        = "ChangeInCapacity"
#   cooldown              = 300
#   autoscaling_group_name = aws_autoscaling_group.app.name
# }

# # CloudWatch Alarm - High CPU
# resource "aws_cloudwatch_metric_alarm" "cpu_high" {
#   alarm_name          = "${var.project_name}-${var.environment}-cpu-high"
#   comparison_operator = "GreaterThanThreshold"
#   evaluation_periods  = "2"
#   metric_name         = "CPUUtilization"
#   namespace           = "AWS/EC2"
#   period              = "300"
#   statistic           = "Average"
#   threshold           = "70"
#   alarm_description   = "This metric monitors ec2 cpu utilization"
#   alarm_actions       = [aws_autoscaling_policy.scale_up.arn]

#   dimensions = {
#     AutoScalingGroupName = aws_autoscaling_group.app.name
#   }
# }

# # CloudWatch Alarm - Low CPU
# resource "aws_cloudwatch_metric_alarm" "cpu_low" {
#   alarm_name          = "${var.project_name}-${var.environment}-cpu-low"
#   comparison_operator = "LessThanThreshold"
#   evaluation_periods  = "2"
#   metric_name         = "CPUUtilization"
#   namespace           = "AWS/EC2"
#   period              = "300"
#   statistic           = "Average"
#   threshold           = "30"
#   alarm_description   = "This metric monitors ec2 cpu utilization"
#   alarm_actions       = [aws_autoscaling_policy.scale_down.arn]

#   dimensions = {
#     AutoScalingGroupName = aws_autoscaling_group.app.name
#   }
# }
