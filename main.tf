resource "aws_s3_bucket" "this" {
  bucket = var.s3_name_prefix != null ? "${var.s3_name_prefix}-${var.project}-${var.env}-${data.aws_region.this.region}" : null
  region = local.region
  lifecycle {
    prevent_destroy = false
  }

  tags = merge(
    var.tags,
    {
      Environment = lower(var.env)
      Project     = lower(var.project)
      Region      = lower(var.aws_region)
      # Region     = lower(data.aws_region.this.region)
    }
  )
}
resource "aws_s3_bucket_versioning" "this" {
  depends_on = [aws_s3_bucket.this]
  bucket     = aws_s3_bucket.this.id
  versioning_configuration {
    status = var.versioning
  }
}
resource "aws_s3_bucket_lifecycle_configuration" "this" {
  depends_on = [aws_s3_bucket_versioning.this]
  bucket     = aws_s3_bucket.this.id
  rule {
    id     = "default"
    status = "Enabled"
    noncurrent_version_expiration {
      noncurrent_days = var.default_retention_noncurrent_days
    }
  }
  rule {
    id     = "archive_retention"
    status = "Enabled"
    noncurrent_version_expiration {
      noncurrent_days = var.archive_retention_noncurrent_days
    }
    filter {
      prefix = "archives"
    }
  }
}
resource "aws_s3_bucket_public_access_block" "this" {
  depends_on              = [aws_s3_bucket_lifecycle_configuration.this]
  bucket                  = aws_s3_bucket.this.id
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

resource "aws_s3_bucket_metric" "enable-metrics-bucket" {
  bucket = "${var.s3_name_prefix}-${var.project}-${var.env}-${data.aws_region.this.region}"
  name   = "EntireBucket"
}

# KMS-backed server side encryption resource (created only when enable_kms is true)
resource "aws_s3_bucket_server_side_encryption_configuration" "this_kms" {
  depends_on = [aws_s3_bucket_public_access_block.this]
  count      = var.enable_kms ? 1 : 0
  bucket     = aws_s3_bucket.this.bucket
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = local.kms_master_key_id
    }
  }
}

# AES256 server side encryption resource (created only when enable_kms is false)
resource "aws_s3_bucket_server_side_encryption_configuration" "this_aes256" {
  depends_on = [aws_s3_bucket_public_access_block.this]
  count      = var.enable_kms ? 0 : 1
  bucket     = aws_s3_bucket.this.bucket
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_kms_key" "this" {
  depends_on              = [data.aws_iam_policy_document.s3_kms_policy]
  count                   = var.enable_kms && var.kms_key_id == null ? 1 : 0
  description             = "KMS Encryption Key for bucket ${var.s3_name_prefix}-${var.project}-${var.env}-${data.aws_region.this.region}"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  policy                  = data.aws_iam_policy_document.s3_kms_policy.json
  tags = merge(
    var.tags,
    {
      Environment = lower(var.env)
      Project     = lower(var.project)
      Region      = lower(var.aws_region)
      # Region     = lower(data.aws_region.this.region)
    }
  )
}

# Create an alias for the generated key
resource "aws_kms_alias" "this" {
  depends_on    = [aws_kms_key.this]
  count         = var.enable_kms && var.kms_key_id == null ? 1 : 0
  name          = "alias/${var.s3_name_prefix}-${var.project}-${var.env}-${data.aws_region.this.region}"
  target_key_id = aws_kms_key.this[0].arn
}


