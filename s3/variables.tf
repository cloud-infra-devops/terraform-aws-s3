variable "bucket_name" {
  description = "Name of the S3 bucket to create"
  type        = string
}

variable "project" {
  description = "Project name"
  type        = string
  default     = "duke-energy-aim"
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

variable "force_destroy" {
  description = "Destroy bucket even if not empty"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

variable "enable_kms" {
  description = "If true, use SSE-KMS for bucket encryption. If false, AES256 (SSE-S3) is used."
  type        = bool
  default     = true
}

variable "create_kms" {
  description = "If true and enable_kms is true, create a new KMS key. If false, provide kms_key_arn."
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "ARN of an existing KMS key to use (if enable_kms = true and create_kms = false)"
  type        = string
  default     = ""
}

variable "kms_alias" {
  description = "Optional alias name for created KMS key (e.g. alias/my-key). Only used if create_kms = true"
  type        = string
  default     = ""
}

variable "create_logging_bucket" {
  description = "If true, create the logging (target) bucket. Otherwise provide logging_bucket_name (module will not attach parser to an external bucket)."
  type        = bool
  default     = false
}

variable "logging_bucket_name" {
  description = "Name of the S3 bucket that will receive server access logs"
  type        = string
  default     = ""
}

variable "logging_prefix" {
  description = "Prefix to use for server access logs in the target logging bucket"
  type        = string
  default     = "access-logs/"
}

variable "enable_cloudtrail" {
  description = "If true, create (or use existing) a CloudTrail that records S3 data events for this bucket and send events to CloudWatch Logs"
  type        = bool
  default     = true
}

variable "use_existing_cloudtrail" {
  description = "If true, do not create a CloudTrail. Provide existing_cloudtrail_name (and optionally arn)."
  type        = bool
  default     = false
}

variable "existing_cloudtrail_name" {
  description = "Name of existing CloudTrail to use if use_existing_cloudtrail = true"
  type        = string
  default     = ""
}

variable "existing_cloudtrail_arn" {
  description = "ARN of existing CloudTrail to use if use_existing_cloudtrail = true (optional)"
  type        = string
  default     = ""
}

variable "use_existing_cloudwatch_log_group" {
  description = "If true, use an existing CloudWatch Log Group name instead of creating a new one"
  type        = bool
  default     = false
}

variable "existing_cloudwatch_log_group_name" {
  description = "Name of existing CloudWatch Log Group to use if use_existing_cloudwatch_log_group = true"
  type        = string
  default     = ""
}

variable "create_cloudwatch_log_group" {
  description = "Whether to create a new CloudWatch Log Group for CloudTrail"
  type        = bool
  default     = true
}

variable "cloudwatch_log_group_name" {
  description = "CloudWatch Log Group name for CloudTrail S3 data events (used when not using an existing log group)"
  type        = string
  default     = ""
}

variable "cloudwatch_log_retention_days" {
  description = "Retention days for the CloudWatch Log Group"
  type        = number
  default     = 1
}

variable "alarm_threshold" {
  description = "Threshold for S3 suspicious operation alarm (number of events within evaluation period)"
  type        = number
  default     = 1
}

variable "alarm_evaluation_periods" {
  description = "Number of periods to evaluate metrics for the alarm"
  type        = number
  default     = 1
}

variable "alarm_period_seconds" {
  description = "Period in seconds for alarm evaluation"
  type        = number
  default     = 300
}

# AccessDenied alarm variables
variable "access_denied_threshold" {
  description = "Threshold for AccessDenied alarm (number of AccessDenied events within evaluation period)"
  type        = number
  default     = 1
}

variable "access_denied_evaluation_periods" {
  description = "Evaluation periods for AccessDenied alarm"
  type        = number
  default     = 1
}

# CloudTrail large object metric (from CloudTrail JSON)
variable "large_object_size_bytes" {
  description = "Size in bytes considered a 'large' upload (used by the large object metric filter and Lambda parser). Example: 104857600 = 100MB"
  type        = number
  default     = 104857600
}

variable "large_object_threshold" {
  description = "Threshold for large object uploads alarm (number of large uploads within evaluation period)"
  type        = number
  default     = 1
}

variable "large_object_evaluation_periods" {
  description = "Evaluation periods for large object uploads alarm"
  type        = number
  default     = 1
}

# # SNS variables
# variable "create_sns_topic" {
#   description = "If true, create an SNS topic for alarm notifications"
#   type        = bool
#   default     = false
# }

# variable "sns_topic_name" {
#   description = "Name of SNS topic to create (if create_sns_topic = true)"
#   type        = string
#   default     = ""
# }

# variable "existing_sns_topic_arn" {
#   description = "ARN of an existing SNS topic to use instead of creating one"
#   type        = string
#   default     = ""
# }

# variable "sns_email_subscription" {
#   description = "Optional email to subscribe to the topic (requires confirmation)"
#   type        = string
#   default     = ""
# }

# variable "sns_lambda_subscription_arn" {
#   description = "Optional Lambda function ARN to subscribe to the topic"
#   type        = string
#   default     = ""
# }

# # Log parser (Lambda) variables
# variable "enable_log_parser" {
#   description = "If true and the module creates the logging bucket, create a Lambda that parses server access logs and emits large-object metrics"
#   type        = bool
#   default     = true
# }

# variable "log_parser_runtime" {
#   description = "Lambda runtime for the log parser"
#   type        = string
#   default     = "python3.12"
# }

# # Validation: If enable_kms is true and create_kms is false, require a kms_key_arn
# variable "validation_dummy" {
#   type    = string
#   default = ""
#   validation {
#     condition     = !(var.enable_kms && !var.create_kms && length(trim(var.kms_key_arn)) == 0)
#     error_message = "When enable_kms is true and create_kms is false you must provide kms_key_arn."
#   }
# }
# Cross-variable validation implemented as a runtime check (fails during 'apply' if inputs are invalid).
# Note: Terraform variable validation blocks cannot reference other variables, so we can't validate this at plan time via variable validation.
# If you run Terraform >= 1.2 and prefer fail-fast earlier, add a module-level precondition in the root module where you call this module.

resource "null_resource" "input_validation" {
  # Create this resource only when the combination of inputs is invalid.
  count = var.enable_kms && !var.create_kms && length(trim(var.kms_key_arn)) == 0 ? 1 : 0

  provisioner "local-exec" {
    command = "echo 'Invalid inputs: when enable_kms is true and create_kms is false you must provide kms_key_arn.' >&2; exit 1"
  }
}
