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
  value       = (var.enable_kms && var.create_kms && length(trimspace(var.kms_alias)) > 0) ? aws_kms_alias.this[0].name : ""
}

output "kms_key_alias_arn" {
  description = "Constructed KMS alias ARN for the created alias (if alias provided). Returns empty string when not applicable."
  value       = (var.enable_kms && var.create_kms && length(trimspace(var.kms_alias)) > 0) ? aws_kms_alias.this[0].arn : ""
}

# Detailed encryption info per-bucket this module manages (primary, optional logging, optional cloudtrail storage).
# For buckets not created by the module (e.g., external logging bucket), limited information is returned (name only).
output "buckets_encryption" {
  description = "Map describing encryption configuration for buckets managed by the module. Each entry contains: name, encrypted (bool|null), sse_algorithm (string|null), kms_key_id (string|null). For buckets not created by the module, encrypted/sse_algorithm/kms_key_id may be null."
  value = {
    primary = {
      name          = aws_s3_bucket.this.id
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

output "all_managed_buckets_encrypted" {
  description = "Boolean that is true when all buckets created by this module are configured with server-side encryption (KMS or other) per module-managed resources. External buckets (not created by module) are treated as skipped."
  value = (
    (try(aws_s3_bucket.this.server_side_encryption_configuration[0].rule[0].apply_server_side_encryption_by_default[0].sse_algorithm, "") != "") &&
    (var.create_logging_bucket ? (length(aws_s3_bucket.logging[0].server_side_encryption_configuration) > 0 ? true : false) : true) &&
    ((var.enable_cloudtrail && !var.use_existing_cloudtrail) ? (length(aws_s3_bucket.cloudtrail_bucket[0].server_side_encryption_configuration) > 0 ? true : false) : true)
  )
}

output "cloudtrail_name" {
  description = "CloudTrail name (if cloudtrail is enabled and was created by module)"
  value       = (var.enable_cloudtrail && !var.use_existing_cloudtrail) ? aws_cloudtrail.this[0].name : var.existing_cloudtrail_name
}

output "cloudtrail_arn" {
  description = "CloudTrail ARN (if cloudtrail is enabled and was created by module)"
  value       = (var.enable_cloudtrail && !var.use_existing_cloudtrail) ? aws_cloudtrail.this[0].arn : var.existing_cloudtrail_arn
}
output "cloudwatch_log_group_name" {
  description = "CloudWatch Log Group name used for CloudTrail S3 events (if created or provided)"
  value       = local.cloudwatch_log_group_name
}
output "cloudwatch_log_group_arn" {
  description = "CloudWatch Log Group ARN used for CloudTrail S3 events (if created or provided)"
  value       = local.cloudwatch_log_group_arn
}
