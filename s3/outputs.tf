output "bucket_id" {
  description = "ID (name) of the created S3 bucket"
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "ARN of the created S3 bucket"
  value       = aws_s3_bucket.this.arn
}

output "logging_bucket" {
  description = "Name of the logging bucket (if created or provided)"
  value       = var.create_logging_bucket ? aws_s3_bucket.logging[0].id : var.logging_bucket_name
}

output "kms_key_arn" {
  description = "KMS key ARN used for bucket encryption (if SSE-KMS enabled)"
  value       = var.enable_kms ? (var.create_kms ? aws_kms_key.this[0].arn : var.kms_key_arn) : ""
}

output "kms_key_alias" {
  description = "Alias name for the created KMS key (if create_kms = true and alias provided). Returns empty string when not applicable."
  value       = (var.enable_kms && var.create_kms && length(trim(var.kms_alias)) > 0) ? aws_kms_alias.this[0].name : ""
}

output "kms_key_alias_arn" {
  description = "Constructed KMS alias ARN for the created alias (if alias provided). Returns empty string when not applicable."
  value       = (var.enable_kms && var.create_kms && length(trim(var.kms_alias)) > 0) ? "arn:aws:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${var.kms_alias}" : ""
}

output "buckets_encryption" {
  description = "Map describing encryption configuration for buckets managed by the module. Each entry contains: name, encrypted (bool|null), sse_algorithm (string|null), kms_key_id (string|null). For buckets not created by the module, encrypted/sse_algorithm/kms_key_id may be null."
  value = {
    primary = {
      name = aws_s3_bucket.this.id
      # The main bucket always configures server_side_encryption_configuration in this module,
      # so we retrieve the algorithm and potential kms key id from the resource.
      encrypted     = true
      sse_algorithm = try(aws_s3_bucket.this.server_side_encryption_configuration[0].rule[0].apply_server_side_encryption_by_default[0].sse_algorithm, "")
      kms_key_id    = var.enable_kms ? (var.create_kms ? aws_kms_key.this[0].arn : var.kms_key_arn) : ""
    }

    logging = var.create_logging_bucket ? {
      name          = aws_s3_bucket.logging[0].id
      encrypted     = length(aws_s3_bucket.logging[0].server_side_encryption_configuration) > 0 ? true : false
      sse_algorithm = length(aws_s3_bucket.logging[0].server_side_encryption_configuration) > 0 ? try(aws_s3_bucket.logging[0].server_side_encryption_configuration[0].rule[0].apply_server_side_encryption_by_default[0].sse_algorithm, "") : ""
      kms_key_id    = (var.enable_kms && length(aws_s3_bucket.logging[0].server_side_encryption_configuration) > 0) ? (var.create_kms ? aws_kms_key.this[0].arn : var.kms_key_arn) : ""
      } : {
      name          = var.logging_bucket_name
      encrypted     = null
      sse_algorithm = null
      kms_key_id    = null
    }

    cloudtrail = (var.enable_cloudtrail && !var.use_existing_cloudtrail) ? {
      name          = aws_s3_bucket.cloudtrail_bucket[0].id
      encrypted     = length(aws_s3_bucket.cloudtrail_bucket[0].server_side_encryption_configuration) > 0 ? true : false
      sse_algorithm = length(aws_s3_bucket.cloudtrail_bucket[0].server_side_encryption_configuration) > 0 ? try(aws_s3_bucket.cloudtrail_bucket[0].server_side_encryption_configuration[0].rule[0].apply_server_side_encryption_by_default[0].sse_algorithm, "") : ""
      kms_key_id    = (var.enable_kms && length(aws_s3_bucket.cloudtrail_bucket[0].server_side_encryption_configuration) > 0) ? (var.create_kms ? aws_kms_key.this[0].arn : var.kms_key_arn) : ""
      } : {
      name          = (var.enable_cloudtrail && var.use_existing_cloudtrail) ? var.existing_cloudtrail_name : ""
      encrypted     = null
      sse_algorithm = null
      kms_key_id    = null
    }
  }
}

# Simple boolean check that all buckets created by this module are encrypted when SSE-KMS or SSE-S3 expected.
# - Primary bucket is required to be encrypted by this module configuration -> check against its SSE configuration.
# - If logging bucket is created, ensure it has server-side encryption configured (true if KMS configured; else may be false).
# - If cloudtrail bucket is created by this module, ensure it has server-side encryption configured (true if KMS configured; else may be false).
#
# For buckets not created by the module (external ones) this check treats them as 'skipped' (true) so the boolean only reflects the resources the module manages.
output "all_managed_buckets_encrypted" {
  description = "Boolean that is true when all buckets created by this module are configured with server-side encryption (KMS or other) per module-managed resources. External buckets (not created by module) are treated as skipped."
  value = (
    # Primary bucket encryption - module always configures it, so check for presence of configuration
    (try(aws_s3_bucket.this.server_side_encryption_configuration[0].rule[0].apply_server_side_encryption_by_default[0].sse_algorithm, "") != "") &&
    # Logging bucket: if created, check encryption present; if not created, consider it satisfied/skipped.
    (var.create_logging_bucket ? (length(aws_s3_bucket.logging[0].server_side_encryption_configuration) > 0 ? true : false) : true) &&
    # CloudTrail bucket: if created by module, check encryption present; if not created or using existing CloudTrail, consider satisfied/skipped.
    ((var.enable_cloudtrail && !var.use_existing_cloudtrail) ? (length(aws_s3_bucket.cloudtrail_bucket[0].server_side_encryption_configuration) > 0 ? true : false) : true)
  )
}

output "cloudtrail_name" {
  description = "CloudTrail name (if cloudtrail is enabled and was created by module)"
  value       = (var.enable_cloudtrail && !var.use_existing_cloudtrail) ? aws_cloudtrail.this[0].name : var.existing_cloudtrail_name
}

output "cloudwatch_log_group" {
  description = "CloudWatch Log Group name used for CloudTrail S3 events (if created or provided)"
  value       = local.cloudwatch_log_group_name
}

# output "sns_topic_arn" {
#   description = "SNS topic ARN used for alarm notifications (if created or provided)"
#   value       = local.sns_topic_arn
# }

# output "log_parser_lambda" {
#   description = "Log parser Lambda ARN (if created)"
#   value       = var.enable_log_parser && var.create_logging_bucket ? aws_lambda_function.log_parser[0].arn : ""
# }
