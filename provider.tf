# Specify Terraform Version
terraform {
  backend "s3" {
    bucket         = "illiasu-3-tier-app"
    key            = "3tier-dev/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "illiasu-3-tier-lock"
    encrypt        = true
  }
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.25.0"
    }
  }
}

# Specify AWS provider
provider "aws" {
  region = var.aws_region
}