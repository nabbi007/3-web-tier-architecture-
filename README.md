# 3-Tier Web Application Infrastructure

A scalable, secure 3-tier web application infrastructure deployed on AWS using Terraform. This project implements a Kanban task management application with proper separation of concerns across presentation, application, and data tiers.

## 🏗️ Architecture Overview

This infrastructure implements a classic 3-tier architecture pattern:

### **Tier 1: Presentation Layer (Web Tier)**
- **Application Load Balancer (ALB)** - Distributes incoming HTTP traffic
- **Public Subnets** - Host the ALB across multiple Availability Zones
- **Security Groups** - Allow HTTP/HTTPS traffic from the internet

### **Tier 2: Application Layer (App Tier)**
- **Auto Scaling Group (ASG)** - Manages EC2 instances running the Node.js application
- **Private Subnets** - Host application servers with no direct internet access
- **NAT Gateway** - Provides outbound internet access for application servers
- **Systems Manager (SSM)** - Secure shell access without SSH keys or bastion hosts

### **Tier 3: Data Layer (Database Tier)**
- **Amazon RDS MySQL** - Managed database service
- **Private DB Subnets** - Isolated database tier with no internet access
- **AWS Secrets Manager** - Secure storage and rotation of database credentials
- **Encryption** - Data encrypted at rest and in transit

## 📁 Project Structure

```
3-web-tier-architecture-/
├── main.tf                 # Root module orchestrating all components
├── variables.tf            # Input variables and configuration
├── outputs.tf             # Output values (ALB DNS, RDS endpoint, etc.)
├── provider.tf            # AWS provider configuration
├── modules/
│   ├── networking/        # VPC, subnets, routing, NAT gateway
│   ├── security/          # Security groups and IAM roles
│   ├── alb/              # Application Load Balancer and target groups
│   ├── compute/          # EC2 instances, Auto Scaling Group, Launch Template
│   └── database/         # RDS instance, subnet groups, secrets
└── scripts/
    └── user-data.sh      # EC2 initialization script
```

## 🔧 Module Descriptions

### **Networking Module** (`modules/networking/`)
- Creates VPC with DNS support enabled
- Provisions public, private app, and private DB subnets across 2 AZs
- Sets up Internet Gateway and single NAT Gateway for cost optimization
- Configures route tables for proper traffic flow

### **Security Module** (`modules/security/`)
- **Web Security Group**: Allows HTTP (80) and HTTPS (443) from internet
- **App Security Group**: Allows HTTP from ALB security group only
- **DB Security Group**: Allows MySQL (3306) from app security group only
- Implements principle of least privilege access

### **ALB Module** (`modules/alb/`)
- Application Load Balancer in public subnets
- Target group with health checks on `/health` endpoint
- HTTP listener (HTTPS optional with certificate)
- Automatic target registration with Auto Scaling Group

### **Compute Module** (`modules/compute/`)
- Launch Template with Amazon Linux 2023 AMI
- Auto Scaling Group with ELB health checks
- IAM roles for Secrets Manager and SSM access
- User data script for automatic application deployment

### **Database Module** (`modules/database/`)
- RDS MySQL instance in private subnets
- Automated password generation and storage in Secrets Manager
- Encryption at rest with AWS managed keys
- Automated backups and maintenance windows

## 🚀 Deployment Instructions

### Prerequisites
- AWS CLI configured with appropriate permissions
- Terraform >= 1.0 installed
- Git repository access for the Kanban application

### Step 1: Clone and Navigate
```bash
git clone <your-repo-url>
cd 3tier-iac/3-web-tier-architecture-
```

### Step 2: Review and Customize Variables
Edit `variables.tf` to customize:
```hcl
variable "aws_region" {
  default = "eu-west-1"  # Change to your preferred region
}

variable "environment" {
  default = "dev"        # dev, staging, prod
}

variable "git_repo_url" {
  default = "https://github.com/nabbi007/Kanban-app.git"
}
```

### Step 3: Initialize Terraform
```bash
terraform init
```

### Step 4: Plan Deployment
```bash
terraform plan
```

### Step 5: Deploy Infrastructure
```bash
terraform apply
```

### Step 6: Access Your Application
After deployment, get the ALB DNS name:
```bash
terraform output alb_dns
```

Access your application at: `http://<alb-dns-name>/`

## 📊 Variables and Outputs

### Key Input Variables
| Variable | Description | Default |
|----------|-------------|---------|
| `aws_region` | AWS deployment region | `eu-west-1` |
| `environment` | Environment name | `dev` |
| `vpc_cidr` | VPC CIDR block | `10.0.0.0/16` |
| `instance_type` | EC2 instance type | `t3.micro` |
| `db_name` | Database name | `kanbandb` |
| `certificate_arn` | SSL certificate ARN (optional) | `""` |

### Key Outputs
| Output | Description |
|--------|-------------|
| `alb_dns` | Application Load Balancer DNS name |
| `rds_endpoint` | RDS database endpoint |
| `db_secret_name` | Secrets Manager secret name |
| `asg_name` | Auto Scaling Group name |

## 🔍 Testing Connectivity

### Test ALB Connectivity
```bash
# Get ALB DNS name
terraform output alb_dns

# Test HTTP connectivity
curl http://<alb-dns-name>/

# Test health endpoint
curl http://<alb-dns-name>/health
```

### Test ICMP (Ping) to Application Servers
Since no bastion host is used, connect via AWS Systems Manager:

1. **Via AWS Console:**
   - Go to Systems Manager → Session Manager
   - Select your application instance
   - Start session

2. **Via AWS CLI:**
   ```bash
   # List instances
   aws ec2 describe-instances --filters "Name=tag:Name,Values=3tier-dev-app"
   
   # Connect to instance
   aws ssm start-session --target <instance-id>
   ```

3. **Test connectivity from within instance:**
   ```bash
   # Ping other app instances
   ping <private-ip-of-other-instance>
   
   # Test database connectivity
   mysql -h <rds-endpoint> -u admin -p
   ```

## 🛡️ Security Features

- **Network Isolation**: Multi-tier subnet architecture with proper routing
- **Security Groups**: Restrictive inbound rules following least privilege
- **No SSH Keys**: Secure access via AWS Systems Manager Session Manager
- **Encrypted Storage**: RDS encryption at rest with AWS managed keys
- **Secrets Management**: Database credentials stored in AWS Secrets Manager
- **Private Subnets**: Application and database tiers have no direct internet access

## 🔧 Maintenance and Operations

### Scaling
- Auto Scaling Group automatically adjusts capacity based on demand
- Modify ASG parameters in `modules/compute/variables.tf`

### Updates
- Application updates trigger rolling deployment via instance refresh
- Database schema changes can be applied via SSM sessions

### Monitoring
- CloudWatch logs enabled for RDS
- Application logs available via CloudWatch agent (if configured)
- ALB access logs can be enabled for detailed request analysis

### Backup and Recovery
- RDS automated backups with 7-day retention
- Point-in-time recovery available
- Secrets Manager automatic rotation (can be enabled)

## 🧹 Cleanup

To destroy all resources:
```bash
terraform destroy
```

**Warning**: This will permanently delete all resources including the database. Ensure you have backups if needed.

## 📸 Screenshots Documentation

This section provides visual documentation of the deployed infrastructure. Screenshots are stored in the `screenshots/` directory.

### Available Screenshots

#### 1. **Terraform Deployment Output** 📋
![Terraform Output](screenshots/output.png)
*Shows successful Terraform apply with all resource outputs including ALB DNS name, RDS endpoint, and Auto Scaling Group details*

#### 2. **Application Load Balancer Testing** 🌐
![ALB Curl Test](screenshots/curl_alb.png)
*Demonstrates successful HTTP connectivity to the ALB endpoint and application health check response*

#### 3. **EC2 Instances & Auto Scaling Group** 🖥️
![EC2 Dashboard](screenshots/ec2.png)
*Shows running EC2 instances managed by the Auto Scaling Group in private subnets*

#### 4. **VPC Network Architecture** 🏗️
![VPC Overview](screenshots/vpc.png)
*Displays the complete VPC setup with public and private subnets across multiple Availability Zones*

#### 4. **RDS** 🏗️
![VPC Overview](screenshots/rds.png)
*Showing the RDS created*

### Additional Screenshots to Capture

For complete documentation, consider capturing these additional screenshots:

#### 5. **RDS Database Instance** 🗄️
- Navigate to RDS Console → Databases
- Show the MySQL instance in "Available" status
- Display connection endpoint and security group settings
- **Location**: `screenshots/rds_instance.png`

#### 6. **Security Groups Configuration** 🔒
- EC2 Console → Security Groups
- Show all three security groups (web, app, db) with their inbound rules
- Demonstrate proper tier isolation
- **Location**: `screenshots/security_groups.png`

#### 7. **Systems Manager Session** 🔧
- Systems Manager → Session Manager
- Show successful connection to private EC2 instance
- Include ICMP ping test to another instance or RDS endpoint
- **Location**: `screenshots/ssm_session.png`

#### 8. **Auto Scaling Group Details** 📈
- EC2 Console → Auto Scaling Groups
- Show ASG configuration with desired/current capacity
- Display health check settings and target group association
- **Location**: `screenshots/asg_details.png`

#### 9. **Application Load Balancer Dashboard** ⚖️
- EC2 Console → Load Balancers
- Show ALB with healthy target instances
- Display listener rules and target group health
- **Location**: `screenshots/alb_dashboard.png`

#### 10. **Secrets Manager** 🔐
- Secrets Manager Console
- Show the database credentials secret
- Display automatic rotation settings (if enabled)
- **Location**: `screenshots/secrets_manager.png`

### Screenshot Capture Commands

#### Testing ALB Connectivity
```bash
# Get ALB DNS from Terraform output
terraform output alb_dns

# Test application endpoint
curl http://$(terraform output -raw alb_dns)/

# Test health endpoint
curl http://$(terraform output -raw alb_dns)/health
```

#### Testing Database Connectivity via SSM
```bash
# Connect to EC2 instance via SSM
aws ssm start-session --target <instance-id>

# Test database connection (from within EC2)
mysql -h $(terraform output -raw rds_endpoint | cut -d: -f1) -u admin -p

# Test ICMP connectivity between instances
ping <private-ip-of-another-instance>
```

### Screenshot Guidelines

1. **Resolution**: Capture at 1920x1080 or higher for clarity
2. **Format**: Use PNG format for better quality
3. **Content**: Ensure sensitive information (IPs, ARNs) are visible but not credentials
4. **Naming**: Use descriptive filenames matching the documentation
5. **Annotations**: Add arrows or highlights to emphasize key information

### Verification Checklist

- [ ] Terraform apply completed successfully
- [ ] ALB responds to HTTP requests
- [ ] EC2 instances are running and healthy
- [ ] RDS instance is available
- [ ] Security groups properly configured
- [ ] SSM session connectivity works
- [ ] Application serves content correctly
- [ ] Database connectivity from app tier
- [ ] ICMP connectivity between instances
- [ ] All screenshots captured and documented

## 🏗️ Architecture Diagram

![3-Tier Architecture](three-web-tier.drawio)
*Complete architecture diagram showing the 3-tier infrastructure layout*

The architecture diagram illustrates:
- **VPC**: 10.0.0.0/16 with DNS support enabled
- **Public Subnets**: 10.0.1.0/24, 10.0.2.0/24 (ALB placement)
- **Private App Subnets**: 10.0.3.0/24, 10.0.4.0/24 (EC2 instances)
- **Private DB Subnets**: 10.0.5.0/24, 10.0.6.0/24 (RDS placement)
- **Internet Gateway**: Public internet access
- **NAT Gateway**: Outbound internet for private subnets
- **Security Groups**: Layered security with proper isolation
- **Data Flow**: HTTP → ALB → App Servers → Database

## 📝 Notes

- This configuration is optimized for development/testing environments
- For production, consider enabling Multi-AZ RDS, additional security hardening, and comprehensive monitoring
- The single NAT Gateway design reduces costs but creates a single point of failure
- SSL/TLS certificate can be added via AWS Certificate Manager for HTTPS support

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.