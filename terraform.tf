terraform {
  required_version = ">= 1.14.0"
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "6.23.0"
    }
  }
  cloud {
    organization = "cloud-infra-dev"
    workspaces {
      name = "github-actions-oidc-hcp-terraform" # Workspace with VCS driven workflow
      project = "AWS-Cloud-IaC"
    }
  }
}

provider "aws" {
  region = lower(var.aws_region)
  allowed_account_ids = [var.aws_account_id]
}