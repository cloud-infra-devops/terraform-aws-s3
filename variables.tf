variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-west-2"
}

variable "aws_account_id" {
  description = "The AWS account ID to deploy resources"
  type        = string
  default     = "211125325120" #Put AWS Account ID
}

variable "bucket_name" {
  description = "The name of the s3 bucket"
  type        = string
  default     = "374278"
}

