# Terraform S3 Module with Optional KMS, Access Logging, CloudTrail → CloudWatch, SNS Alerts, and Log Parsing

This Terraform module provisions an S3 bucket with strong defaults and integrated monitoring:

- S3 bucket with ACL = private
- Block Public Access enforced
- Optional encryption:
  - SSE-S3 (AES256) by default
  - SSE-KMS using either a created KMS key or an existing KMS key ARN
- S3 server access logging to a logging bucket (created or provided)
- CloudTrail configured to capture S3 data events for the bucket and send them to CloudWatch Logs (or you may reuse an existing CloudTrail / Log Group)
- CloudWatch metric filters and alarms:
  - PutObject/DeleteObject (data events)
  - AccessDenied events
  - Large object uploads (from CloudTrail JSON when available)
  - Large object uploads (from parsing server access logs via a Lambda parser)
- SNS topic support for alarm notifications (create or use existing). Optional email and Lambda subscriptions.
- Lambda-based parser for S3 server access logs to reliably detect large uploads and emit metrics
- Outputs expose ARNs, bucket names, and KMS info and include helpers that confirm encryption status

Why use this module
- Provides a secure default configuration for S3 buckets (private ACL + block public access)
- Integrates monitoring & alerting for suspicious S3 activity
- Supports KMS encryption consistently across primary, logging, and CloudTrail buckets
- Provides both CloudTrail-based and server-access-log-based large-object detection

Quick start (basic)
```hcl
module "s3" {
  source = "./modules/s3_bucket"

  bucket_name           = "my-app-bucket-12345"
  create_logging_bucket = true

  # Use SSE-KMS
  enable_kms  = true
  create_kms  = true
  kms_alias   = "alias/my-app-s3-key"

  # CloudTrail + CloudWatch
  enable_cloudtrail = true

  # Create SNS topic and subscribe an email
  create_sns_topic        = true
  sns_email_subscription  = "alerts@example.com"

  # Log parser settings (only attaches when create_logging_bucket = true)
  enable_log_parser       = true
  large_object_size_bytes = 104857600  # 100 MB

  tags = {
    Owner = "infra-team"
    Env   = "prod"
  }
}
```

Using existing resources
- Use an existing KMS key:
  - set enable_kms = true, create_kms = false, kms_key_arn = "<existing-kms-arn>"
- Use an existing CloudTrail:
  - set use_existing_cloudtrail = true and provide existing_cloudtrail_name and ensure that existing CloudTrail is capturing S3 data events and publishing to the chosen CloudWatch Logs group
- Use an existing CloudWatch Log Group:
  - set use_existing_cloudwatch_log_group = true and existing_cloudwatch_log_group_name = "<log-group-name>"
- Use an existing SNS topic:
  - set existing_sns_topic_arn to the topic ARN and do NOT set create_sns_topic = true

Important behavior details
- Logging bucket parser:
  - Terraform can only attach S3 notifications to buckets it manages. If you supply a logging bucket that is managed outside the module (create_logging_bucket = false), the module will NOT attach the Lambda parser to it.
- SNS email subscriptions:
  - Terraform creates the subscription, but the email recipient must manually confirm the subscription via a confirmation email.
- KMS & encryption:
  - When enable_kms = true and create_kms = true, the module creates one KMS key and configures the primary bucket, the logging bucket (if created), and the CloudTrail storage bucket (if created by module) to use that same key.
  - To avoid Terraform dependency cycles the KMS key policy allows S3 use constrained to the account (aws:SourceAccount). This is both practical and secure for typical usage.
- CloudTrail & CloudWatch:
  - If the module creates the CloudTrail, it also creates the S3 bucket for CloudTrail logs and configures CloudTrail to publish S3 data events for the primary bucket to CloudWatch Logs (Log Group is created unless you provide an existing one).
  - If you supply an existing CloudTrail, the module expects that CloudTrail is already configured to record S3 data events for the primary bucket and publish them to the supplied Log Group.

Variables (high level)
- bucket_name (string) - name of the S3 bucket to create
- enable_kms (bool) - enable SSE-KMS for encryption
- create_kms (bool) - create a new KMS key (when enable_kms = true)
- kms_key_arn (string) - use an existing KMS key (when create_kms = false)
- create_logging_bucket (bool) - create the server-access logging bucket
- logging_bucket_name (string) - name of logging bucket (if not created by module)
- enable_cloudtrail (bool) - create CloudTrail for S3 data events
- use_existing_cloudtrail / use_existing_cloudwatch_log_group - flags for reusing existing resources
- create_sns_topic / existing_sns_topic_arn - SNS topic handling
- enable_log_parser - create Lambda to parse server access logs
- large_object_size_bytes - threshold (bytes) for “large” uploads

Outputs (high level)
- bucket_id, bucket_arn
- logging_bucket (name)
- kms_key_arn, kms_key_alias, kms_key_alias_arn
- cloudtrail_name, cloudwatch_log_group (name)
- sns_topic_arn
- log_parser_lambda (ARN)
- buckets_encryption (map) — explicit encryption info per managed bucket
- all_managed_buckets_encrypted (bool) — quick pass/fail whether module-managed buckets are encrypted

Operational notes & troubleshooting
- Bucket name conflicts: S3 bucket names must be globally unique. Use unique suffixes or naming strategy.
- Permissions / KMS Denied: If you use an existing KMS key, ensure the key policy allows S3 and the module principals to use the key (and CloudTrail to use it if you configure log encryption).
- SNS email subscription appears stuck: check recipient inbox and confirm subscription from the confirmation email.
- Lambda parser doesn't trigger: verify the logging bucket was created by this module; only then does module configure S3 → Lambda notification and add the necessary Lambda permission.
- CloudTrail logs missing: verify CloudTrail is enabled, capturing S3 data events for your bucket, and that CloudWatch Logs role ARN is set and has permissions.

Testing & validation suggestions
- After apply:
  - Confirm in console: primary S3 bucket -> Properties -> Default encryption set correctly
  - Confirm CloudTrail is present and event history shows S3 data events for the bucket
  - Check CloudWatch Log Group for log entries
  - Check CloudWatch metrics (namespaces `S3/CloudTrail` and `S3/ServerAccessLogs`)
  - If SNS email subscription was configured, confirm email and check SNS subscription status
  - If parser enabled: upload some large test objects (or create artificial server access logs) and check CloudWatch metrics and Lambda logs

Limitations and extension ideas
- Module attaches S3 notifications only to buckets it creates. If you want the parser attached to an externally managed logging bucket, either:
  - attach the notification outside the module using the Lambda ARN produced by this module, or
  - extend the module to accept an external bucket resource reference (we can add that).
- CloudTrail-based large-object detection depends on CloudTrail including size fields in the event JSON. For reliable object-size detection, the server access log parser is recommended.

Support / next steps
- Want the module to attach the parser to an external logging bucket? I can add an input to accept the bucket resource (caller-managed) and safely create the S3 notification.
- Want CloudTrail log objects encrypted with the KMS key? I can add explicit CloudTrail encryption configuration as a follow-up.
- Need additional alarms or runbook links on alarms? I can attach SNS actions or custom actions.

If you want, I can also produce a short example root module (complete Terraform folder) that demonstrates a typical production setup including SNS, email subscription, and example values.
