data "aws_ssm_parameter" "ami" {
  name = var.ami_ssm_parameter_name
}

# Launch Template
resource "aws_launch_template" "app" {
  name_prefix            = "${var.project_name}-${var.environment}-app-"
  image_id               = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [var.app_sg_id]

  user_data = base64encode(templatefile("${path.root}/scripts/user-data.sh", {
    GIT_REPO_URL = var.git_repo_url
    GIT_BRANCH   = var.git_branch
    DB_HOST      = split(":", var.db_endpoint)[0]
    DB_USER      = var.db_username
    DB_PASSWORD  = var.db_password
    DB_NAME      = var.db_name
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
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
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
