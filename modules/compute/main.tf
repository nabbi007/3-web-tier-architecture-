data "aws_ssm_parameter" "ami" {
  name = var.ami_ssm_parameter_name
}

# Launch Template
resource "aws_launch_template" "app" {
  name_prefix            = "${var.project_name}-${var.environment}-app-"
  image_id               = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [var.app_sg_id]
  
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -e
    
    # Log everything
    exec > >(tee /var/log/user-data.log)
    exec 2>&1
    
    echo "Starting instance setup..."
    
    # Update and install dependencies
    apt-get update -y
    apt-get install -y git nodejs npm
    
    # Clone application from Git
    cd /opt
    git clone ${var.app_repo_url} kanban-app
    cd kanban-app
    
    # Set environment variables
    cat > .env <<ENV
    DB_HOST=${split(":", var.db_endpoint)[0]}
    DB_USER=${var.db_username}
    DB_PASSWORD=${var.db_password}
    DB_NAME=${var.db_name}
    PORT=80
    ENV
    
    # Install dependencies
    npm install --production
    
    # Create systemd service
    cat > /etc/systemd/system/kanban.service <<SERVICE
    [Unit]
    Description=Kanban API Service
    After=network.target
    
    [Service]
    Type=simple
    User=root
    WorkingDirectory=/opt/kanban-app
    EnvironmentFile=/opt/kanban-app/.env
    ExecStart=/usr/bin/node server.js
    Restart=always
    RestartSec=10
    
    [Install]
    WantedBy=multi-user.target
    SERVICE
    
    # Start service
    systemctl daemon-reload
    systemctl enable kanban
    systemctl start kanban
    
    echo "Setup completed!"
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
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 300
    }
    triggers = ["tag"]
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes = []
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

  tag {
    key                 = "AppVersion"
    value               = var.app_version
    propagate_at_launch = true
  }
}

# Attach ASG to Target Group
resource "aws_autoscaling_attachment" "app" {
  autoscaling_group_name = aws_autoscaling_group.app.id
  lb_target_group_arn    = var.target_group_arn
}
