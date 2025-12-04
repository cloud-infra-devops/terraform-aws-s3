```markdown
# Terraform S3 module with optional KMS, access logging and CloudWatch monitoring (with SNS + log parsing)

This module creates an S3 bucket with:

- ACL set to `private`
- Block public access (via `aws_s3_bucket_public_access_block`)
- Server access logging to another S3 bucket (can be created by the module or provided)
- Optional KMS encryption (create a KMS key or use an existing KMS key ARN). If not using KMS, SSE-S3 (AES256) is used.
- CloudTrail configured to capture S3 data events for the bucket and send events to CloudWatch Logs (or you can point to an existing CloudTrail and/or CloudWatch Log Group).
- IAM role & policy used by CloudTrail to publish CloudWatch Logs (policy tightened to the specific CloudWatch Log Group ARN)
- CloudWatch Log Group, multiple metric filters and alarms:
  - S3 data events (PutObject/DeleteObject) metric + alarm
  - AccessDenied events metric + alarm
  - Large object uploads metric + alarm (from CloudTrail metric filter)
- Alternative large-object detection path:
  - A Lambda function that parses S3 server access logs (delivered to the logging bucket) and emits a CloudWatch metric for uploads larger than configured threshold.
  - The Lambda is only attached to the logging bucket if the module creates that logging bucket (create_logging_bucket = true). If you supply an existing logging bucket (create_logging_bucket = false), the module will not create the S3 -> Lambda notification.
- SNS integration:
  - Create an SNS topic (or use an existing one) and optionally add an email subscription and/or a Lambda subscription.
  - CloudWatch alarms will use the SNS topic as alarm actions.

Usage example:

```hcl
module "s3" {
  source = "./modules/s3_bucket"

  bucket_name            = "my-app-bucket-12345"
  logging_bucket_name    = "my-app-bucket-logs-12345"
  logging_prefix         = "s3-access-logs/"
  create_logging_bucket  = true

  # Encryption: AES256 (default) or enable KMS:
  enable_kms             = true
  create_kms             = true
  kms_alias              = "alias/my-app-s3-key"

  # CloudTrail and CloudWatch
  enable_cloudtrail      = true
  create_sns_topic       = true
  sns_email_subscription = "alerts@example.com"

  # Log parser / large object threshold
  enable_log_parser = true
  large_object_size_bytes = 104857600 # 100 MB

  # Optionally, use existing CloudWatch Log Group or CloudTrail
  use_existing_cloudwatch_log_group = false
  existing_cloudwatch_log_group_name = ""

  tags = {
    "Owner" = "team-x"
    "Env"   = "prod"
  }
}
```

Important notes:
- The Lambda-based server-access-log parser only attaches to the logging bucket if the module created that bucket (create_logging_bucket = true). Terraform cannot safely add an S3 notification to an S3 bucket it does not manage.
- If you want the module to connect the parser to an existing logging bucket managed outside the module, we can add a mode to accept an existing bucket resource (you would need to pass the bucket resource via root module).
- If you set use_existing_cloudtrail = true or use_existing_cloudwatch_log_group = true, make sure you supply the corresponding existing names/ARNs so the module will not attempt to create those resources.
- Alarms are created with SNS action(s) only if a topic is supplied or the module creates one. Attach additional alarm actions (e.g., runbooks) from the caller if needed.

If you'd like, I can:
- Add support to attach the Lambda parser to an externally managed logging bucket via an input (requires caller to provide the bucket resource or a way to allow S3 notification updates).
- Add automated subscription confirmation handling for email (Terraform creates the subscription but the email owner must confirm).
- Add scheduled cleanup / dead-letter queue for the Lambda parser.
```