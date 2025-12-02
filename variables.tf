# variable "bucket_policy" {
#   description = "Override the resource policy on the bucket"
#   type        = string
#   default     = null
# }

variable "s3_name_prefix" {
  type        = string
  description = "The name of the s3 bucket"
  default     = ""
  validation {
    condition     = var.s3_name_prefix != ""
    error_message = "s3_name_prefix must not be empty"
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags to be applied to created resources"
  default     = {}
}

variable "project" {
  description = "Project name"
  type        = string
  default     = "json-to-csv-datapipeline"
}

variable "env" {
  description = "value representing the environment (e.g., dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["poc", "sbx", "dev", "qa", "prod"], var.env)
    error_message = "Environment must be one of: poc, sbx, dev, qa, prod"
  }
  default = "sbx"
}

variable "default_retention_noncurrent_days" {
  description = "retention non-concurrent days"
  type    = string
  default = 180
}

variable "archive_retention_noncurrent_days" {
  description = "archive retention non-concurrent days"
  type    = string
  default = 90
}

variable "versioning" {
  description = "Bucket Versioning"
  type    = string
  default = "Disabled"
  validation {
    condition     = contains(["Enabled", "Disabled"], var.versioning)
    error_message = "S3 Bucket Versioning must be one of: Enabled or Disabled"
  }
}
# variable "read_principals" {
#   description = "Principal allowed to read from the bucket (default: current account)"
#   type        = list(string)
#   default     = []
# }
# variable "read_tags" {
#   description = "Tags required on principals reading to the bucket"
#   type        = map(string)
#   default     = {}
# }
# variable "readwrite_principals" {
#   description = "Principal allowed to read and write to the bucket (default: current account)"
#   type        = list(string)
#   default     = []
# }
# variable "readwrite_tags" {
#   description = "Tags required on principals writing to the bucket"
#   type        = map(string)
#   default     = {}
# }
variable "enable_kms" {
  description = "Enable KMS-backed server-side encryption (aws:kms). If false, AES256 will be used."
  type        = bool
  validation {
    condition     = var.enable_kms != null ? var.enable_kms == true || var.enable_kms == false : true
    error_message = "enable_kms must be a boolean value (true or false) or null"
  }
  default     = null
}
variable "kms_key_id" {
  description = "Optional KMS CMK ID or ARN to use for aws:kms encryption. If null, a new CMK will be created when `enable_kms` is true."
  type        = string
  default     = null
}
