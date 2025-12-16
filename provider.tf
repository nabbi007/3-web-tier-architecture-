# Specify Terraform Version
terraform {
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