terraform {
  required_version = ">= 1.14.0"
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "6.23.0"
    }
  }
}

provider "aws" {
  region = lower(data.aws_region.this.region)
}