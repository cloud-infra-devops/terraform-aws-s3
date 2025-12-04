output "s3_bucket_name" {
  value = module.s3-bucket.bucket_id
}

output "s3_bucket_arn" {
  value = module.s3-bucket.bucket_arn
}

output "s3_logging_bucket" {
  value = module.s3-bucket.logging_bucket
}

output "kms_key_arn" {
  value = module.s3-bucket.kms_key_arn
}

output "kms_key_alias" {
  value = module.s3-bucket.kms_key_alias
}
output "kms_key_alias_arn" {
  value = module.s3-bucket.kms_key_alias_arn
}

output "s3_buckets_encryption" {
  value = module.s3-bucket.buckets_encryption
}

output "cloudtrail_name" {
  value = module.s3-bucket.cloudtrail_name
}
output "cloudtrail_arn" {
  value = module.s3-bucket.cloudtrail_arn
}
output "cloudwatch_log_group_name" {
  value = module.s3-bucket.cloudwatch_log_group_name
}
output "cloudwatch_log_group_arn" {
  value = module.s3-bucket.cloudwatch_log_group_arn
}
