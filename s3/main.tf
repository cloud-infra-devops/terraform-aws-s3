data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  # account_id  = data.aws_caller_identity.current.account_id
  account_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
  # Detailed encryption info per-bucket this module manages (primary, optional logging, optional cloudtrail storage).
  # For buckets not created by the module (e.g., external logging bucket), limited information is returned (name only).
  logging_bucket_obj        = var.create_logging_bucket ? aws_s3_bucket.logging[0] : null
  cloudtrail_bucket_obj     = (var.enable_cloudtrail && !var.use_existing_cloudtrail) ? aws_s3_bucket.cloudtrail_bucket[0] : null
  cloudwatch_log_group_name = var.use_existing_cloudwatch_log_group ? var.existing_cloudwatch_log_group_name : aws_cloudwatch_log_group.cloudtrail[0].name
  cloudwatch_log_group_arn  = var.use_existing_cloudwatch_log_group ? "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:${replace(var.existing_cloudwatch_log_group_name, "/", "%2F")}" : aws_cloudwatch_log_group.cloudtrail[0].arn
  # cloudwatch_log_group_name = var.enable_cloudtrail ? (var.create_cloudwatch_log_group ? aws_cloudwatch_log_group.cloudtrail[0].name : var.existing_cloudwatch_log_group_name) : ""
  # sns_topic_arn             = var.create_sns_topic ? aws_sns_topic.alerts[0].arn : var.existing_sns_topic_arn
}

## s3 bucket policy
data "aws_iam_policy_document" "this" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [local.account_arn]
    }
    actions = [
      "s3:*"
    ]
    resources = [
      "${aws_s3_bucket.this.arn}/*",
      aws_s3_bucket.this.arn
    ]
  }
}

# Optional: create the logging target bucket if requested
resource "aws_s3_bucket" "logging" {
  count         = var.create_logging_bucket ? 1 : 0
  bucket        = var.logging_bucket_name != "" ? var.logging_bucket_name : "${var.bucket_name}-logs"
  force_destroy = true
  tags = merge(var.tags, {
    "Name" = "${var.bucket_name}-logging"
  })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logging" {
  count  = var.create_logging_bucket && var.enable_kms ? 1 : 0
  bucket = aws_s3_bucket.logging[0].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.create_kms ? aws_kms_key.this[0].arn : var.kms_key_arn
    }
  }
}

resource "aws_s3_bucket_acl" "logging" {
  count  = var.create_logging_bucket ? 1 : 0
  bucket = aws_s3_bucket.logging[0].id
  acl    = "log-delivery-write"
}

resource "aws_s3_bucket_public_access_block" "logging" {
  count  = var.create_logging_bucket ? 1 : 0
  bucket = aws_s3_bucket.logging[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# The primary bucket
resource "aws_s3_bucket" "this" {
  depends_on    = [aws_s3_bucket.logging]
  bucket        = var.bucket_name != "" ? "${var.bucket_name}-${var.project}-${var.env}-${data.aws_region.current.region}" : "${var.project}-${var.env}-${data.aws_region.current.region}"
  force_destroy = var.force_destroy
  tags = merge(var.tags, {
    Environment = lower(var.env)
    Project     = lower(var.project)
    Region      = lower(data.aws_region.current.region)
  })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.enable_kms ? "aws:kms" : "AES256"
      kms_master_key_id = var.enable_kms ? (var.create_kms ? aws_kms_key.this[0].arn : var.kms_key_arn) : null
    }
  }
}
resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_policy" "this" {
  depends_on = [aws_s3_bucket_ownership_controls.this, aws_s3_bucket_public_access_block.this]
  bucket     = aws_s3_bucket.this.id
  policy     = data.aws_iam_policy_document.this.json
}

resource "aws_s3_bucket_acl" "s3_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.this]
  bucket     = aws_s3_bucket.this.id
  acl        = "private"
}
resource "aws_s3_bucket_logging" "this" {
  count         = var.create_logging_bucket || var.logging_bucket_name != "" ? 1 : 0
  bucket        = aws_s3_bucket.this.id
  target_bucket = var.logging_bucket_name != "" ? var.logging_bucket_name : aws_s3_bucket.logging[0].id
  target_prefix = "${var.bucket_name}/"
}
# Logging bucket encryption config: created only when logging bucket exists
resource "aws_s3_bucket_server_side_encryption_configuration" "logging" {
  count  = var.create_logging_bucket ? 1 : 0
  bucket = aws_s3_bucket.logging[0].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.enable_kms ? "aws:kms" : "AES256"
      kms_master_key_id = var.enable_kms ? (var.create_kms ? aws_kms_key.this[0].arn : var.kms_key_arn) : null
    }
  }
}
# KMS Key for S3 encryption if requested
resource "aws_kms_key" "this" {
  count                   = var.enable_kms && var.create_kms ? 1 : 0
  description             = "KMS key for S3 buckets - ${var.bucket_name}"
  deletion_window_in_days = 7

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Allow account root full administration of the key
      {
        Sid       = "Enable IAM User Permissions"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = ["*"]
      },
      # Allow S3 service in this account to use the key (for server-side encryption),
      # limited by aws:SourceAccount to this account to reduce scope.
      {
        Sid       = "AllowS3UseOfTheKeyFromThisAccount"
        Effect    = "Allow"
        Principal = { Service = "s3.amazonaws.com" }
        Action = [
          "kms:ReplicateKey",
          "kms:Create*",
          "kms:Describe*",
          "kms:Enable*",
          "kms:List*",
          "kms:Put*",
          "kms:Update*",
          "kms:Revoke*",
          "kms:Disable*",
          "kms:Get*",
          "kms:Delete*",
          "kms:ScheduleKeyDeletion",
          "kms:CancelKeyDeletion",
          "kms:DescribeKey",
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey",
          "kms:GenerateDataKeyWithoutPlaintext"
        ]
        Resource = [aws_s3_bucket.this.arn]
        Condition = {
          "StringEquals" = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    "Name" = "${var.bucket_name}-kms"
  })
}

resource "aws_kms_alias" "this" {
  count         = var.enable_kms && var.create_kms && length(trimspace(var.kms_alias)) > 0 ? 1 : 0
  name          = var.kms_alias
  target_key_id = aws_kms_key.this[0].key_id
}

# Cross-variable validation implemented as runtime checks (fail during 'apply' if inputs are invalid).
# Check kms inputs: if enable_kms = true and create_kms = false then kms_key_arn must be supplied
resource "null_resource" "input_validation_kms" {
  count = var.enable_kms && !var.create_kms && length(trimspace(var.kms_key_arn)) == 0 ? 1 : 0
  provisioner "local-exec" {
    command = "echo 'Invalid inputs: when enable_kms is true and create_kms is false you must provide kms_key_arn.' >&2; exit 1"
  }
}

# Check CloudWatch Log Group inputs when using an existing log group
resource "null_resource" "input_validation_existing_log_group" {
  count = var.use_existing_cloudwatch_log_group && length(trimspace(var.existing_cloudwatch_log_group_name)) == 0 ? 1 : 0
  provisioner "local-exec" {
    command = "echo 'Invalid inputs: use_existing_cloudwatch_log_group is true but existing_cloudwatch_log_group_name is empty.' >&2; exit 1"
  }
}
# CloudWatch Log Group (create or reference existing)
resource "aws_cloudwatch_log_group" "cloudtrail" {
  count             = var.enable_cloudtrail && !var.use_existing_cloudwatch_log_group ? 1 : 0
  name              = var.cloudwatch_log_group_name != "" ? var.cloudwatch_log_group_name : "/aws/cloudtrail/s3/${var.bucket_name}"
  retention_in_days = var.cloudwatch_log_retention_days
  tags              = merge(var.tags, { "Name" = "${var.bucket_name}-cloudtrail-log-group" })
}

# CloudTrail IAM Role and policy: only create when creating a CloudTrail (not when using an existing CloudTrail)
resource "aws_iam_role" "cloudtrail" {
  count = var.enable_cloudtrail && !var.use_existing_cloudtrail ? 1 : 0
  name  = "${var.bucket_name}-cloudtrail-to-cw-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

# Policy allowing CloudTrail to create log streams and put events, restricted to the specific log group ARN (and its streams).
resource "aws_iam_role_policy" "cloudtrail_policy" {
  count = var.enable_cloudtrail && !var.use_existing_cloudtrail ? 1 : 0

  name = "${var.bucket_name}-cloudtrail-to-cw-policy"
  role = aws_iam_role.cloudtrail[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          "${local.cloudwatch_log_group_arn}:*",
          "${local.cloudwatch_log_group_arn}"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup"
        ]
        Resource = [
          "${local.cloudwatch_log_group_arn}"
        ]
      }
    ]
  })
}

# CloudTrail requires an S3 bucket to store event files if we create CloudTrail here
resource "aws_s3_bucket" "cloudtrail_bucket" {
  count  = var.enable_cloudtrail && !var.use_existing_cloudtrail ? 1 : 0
  bucket = "${var.bucket_name}-cloudtrail-logs"
  # acl           = var.allow_bucket_acl ? "private" : null
  force_destroy = true

  tags = merge(var.tags, {
    "Name" = "${var.bucket_name}-cloudtrail-storage"
  })

  # When KMS is enabled, set default SSE to AWS KMS using either the created key or provided key ARN
  dynamic "server_side_encryption_configuration" {
    for_each = var.enable_kms ? [1] : []
    content {
      rule {
        apply_server_side_encryption_by_default {
          sse_algorithm     = "aws:kms"
          kms_master_key_id = var.create_kms ? aws_kms_key.this[0].arn : var.kms_key_arn
        }
      }
    }
  }
}

# CloudTrail storage bucket encryption config: created only when cloudtrail bucket exists
resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail_bucket" {
  count  = var.enable_cloudtrail && !var.use_existing_cloudtrail ? 1 : 0
  bucket = aws_s3_bucket.cloudtrail_bucket[0].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.enable_kms ? "aws:kms" : "AES256"
      kms_master_key_id = var.enable_kms ? (var.create_kms ? aws_kms_key.this[0].arn : var.kms_key_arn) : null
    }
  }
}

# resource "aws_s3_bucket_acl" "cloudtrail_bucket_acl" {
#   count  = var.enable_cloudtrail && !var.use_existing_cloudtrail ? 1 : 0
#   bucket = aws_s3_bucket.cloudtrail_bucket[0].id
#   acl    = "private"
# }

resource "aws_s3_bucket_public_access_block" "cloudtrail_bucket_pab" {
  count  = var.enable_cloudtrail && !var.use_existing_cloudtrail ? 1 : 0
  bucket = aws_s3_bucket.cloudtrail_bucket[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Server-side encryption configuration resources (replaces deprecated inline block)
# # Primary bucket: always create an SSE configuration (either SSE-S3 or SSE-KMS depending on var.enable_kms)
# resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
#   count  = 1
#   bucket = aws_s3_bucket.this.id
#   rule {
#     apply_server_side_encryption_by_default {
#       sse_algorithm     = var.enable_kms ? "aws:kms" : "AES256"
#       kms_master_key_id = var.enable_kms ? (var.create_kms ? aws_kms_key.this[0].arn : var.kms_key_arn) : null
#     }
#   }
# }

resource "aws_cloudtrail" "this" {
  # Explicit dependencies to ensure log group and role/policy are present before CloudTrail creation.
  depends_on = [
    aws_cloudwatch_log_group.cloudtrail,
    aws_iam_role.cloudtrail,
    aws_iam_role_policy.cloudtrail_policy
  ]
  count = var.enable_cloudtrail && !var.use_existing_cloudtrail ? 1 : 0

  name                          = "${var.bucket_name}-cloudtrail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_bucket[0].bucket
  include_global_service_events = false
  enable_logging                = true
  is_multi_region_trail         = false
  cloud_watch_logs_role_arn     = aws_iam_role.cloudtrail[0].arn
  cloud_watch_logs_group_arn    = local.cloudwatch_log_group_arn

  event_selector {
    read_write_type           = "All"
    include_management_events = false

    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::${aws_s3_bucket.this.bucket}/"]
    }
  }

  tags = var.tags
}

# Metric filters and alarms to monitor S3 data events, AccessDenied events and large uploads in CloudTrail logs

resource "aws_cloudwatch_log_metric_filter" "s3_data_events" {
  count          = var.enable_cloudtrail ? 1 : 0
  name           = "${var.bucket_name}-s3-data-events-filter"
  log_group_name = aws_cloudwatch_log_group.cloudtrail[0].name

  # matches PutObject or DeleteObject events from CloudTrail JSON logs
  pattern = "{ $.eventName = \"PutObject\" || $.eventName = \"DeleteObject\" }"

  metric_transformation {
    name          = "${var.bucket_name}_S3DataEvents"
    namespace     = "S3/CloudTrail"
    value         = "1"
    default_value = 0
  }
}

resource "aws_cloudwatch_log_metric_filter" "s3_access_denied" {
  count          = var.enable_cloudtrail ? 1 : 0
  name           = "${var.bucket_name}-s3-access-denied-filter"
  log_group_name = aws_cloudwatch_log_group.cloudtrail[0].name

  # CloudTrail logs include "errorCode" for failed calls; this matches AccessDenied
  pattern = "{ $.errorCode = \"AccessDenied\" }"

  metric_transformation {
    name          = "${var.bucket_name}_S3AccessDenied"
    namespace     = "S3/CloudTrail"
    value         = "1"
    default_value = 0
  }
}

resource "aws_cloudwatch_log_metric_filter" "s3_large_puts" {
  count          = var.enable_cloudtrail ? 1 : 0
  name           = "${var.bucket_name}-s3-large-uploads-filter"
  log_group_name = aws_cloudwatch_log_group.cloudtrail[0].name

  # Attempt to detect large PutObject uploads. CloudTrail payloads may include requestParameters.contentLength or other size fields depending on client.
  # This filter matches PutObject events and a numeric size greater than the configured threshold if the field exists in the log message.
  # Note: CloudWatch Logs filter pattern numeric comparisons are supported when the field exists in the JSON logs.
  pattern = "{ ($.eventName = \"PutObject\") && ($.requestParameters.contentLength > ${var.large_object_size_bytes}) }"

  metric_transformation {
    name          = "${var.bucket_name}_S3LargeUploads"
    namespace     = "S3/CloudTrail"
    value         = "1"
    default_value = 0
  }
}

# Alarm: S3 data events (Put/Delete)
resource "aws_cloudwatch_metric_alarm" "s3_suspicious_ops" {
  count = var.enable_cloudtrail ? 1 : 0

  alarm_name          = "${var.bucket_name}-s3-suspicious-ops"
  alarm_description   = "Alarm for S3 PutObject/DeleteObject events on ${var.bucket_name}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  period              = var.alarm_period_seconds
  threshold           = var.alarm_threshold
  statistic           = "Sum"
  metric_name         = "${var.bucket_name}_S3DataEvents"
  namespace           = "S3/CloudTrail"
  dimensions          = {}
  treat_missing_data  = "notBreaching"
  tags                = var.tags
}

# Alarm: AccessDenied events
resource "aws_cloudwatch_metric_alarm" "s3_access_denied_alarm" {
  count               = var.enable_cloudtrail ? 1 : 0
  alarm_name          = "${var.bucket_name}-s3-access-denied"
  alarm_description   = "Alarm for S3 AccessDenied events on ${var.bucket_name}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.access_denied_evaluation_periods
  period              = var.alarm_period_seconds
  threshold           = var.access_denied_threshold
  statistic           = "Sum"
  metric_name         = "${var.bucket_name}_S3AccessDenied"
  namespace           = "S3/CloudTrail"
  dimensions          = {}
  treat_missing_data  = "notBreaching"
  tags                = var.tags
}

# Alarm: Large object uploads
resource "aws_cloudwatch_metric_alarm" "s3_large_uploads_alarm" {
  count = var.enable_cloudtrail ? 1 : 0

  alarm_name          = "${var.bucket_name}-s3-large-uploads"
  alarm_description   = "Alarm for large S3 PutObject uploads on ${var.bucket_name} (>${var.large_object_size_bytes} bytes)"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.large_object_evaluation_periods
  period              = var.alarm_period_seconds
  threshold           = var.large_object_threshold
  statistic           = "Sum"
  metric_name         = "${var.bucket_name}_S3LargeUploads"
  namespace           = "S3/CloudTrail"
  dimensions          = {}
  treat_missing_data  = "notBreaching"
  tags                = var.tags
}

