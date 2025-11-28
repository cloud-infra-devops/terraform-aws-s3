resource "aws_s3_bucket" "this" {
  # bucket = var.name
  bucket_prefix = var.bucket_prefix != null ? "${var.bucket_prefix}-${var.project}-${var.env}-${data.aws_region.this.region}" : null
  lifecycle {
    prevent_destroy = false
  }

  tags = merge(
    var.tags,
    {
      Name = lower("${var.project}-${var.env}-${data.aws_region.this.region}")
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
  # depends_on = [aws_s3_bucket_server_side_encryption_configuration.this]
  bucket = aws_s3_bucket.this.id
  rule {
    object_ownership = "BucketOwnerPreferred"
    # object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_policy" "this" {
  depends_on = [aws_s3_bucket_ownership_controls.this, aws_s3_bucket_public_access_block.this]
  bucket     = aws_s3_bucket.this.id
  policy     = data.aws_iam_policy_document.bucket.json
}
resource "aws_s3_bucket_acl" "s3_acl" {
  # depends_on = [aws_s3_bucket_policy.this]
  depends_on = [aws_s3_bucket_ownership_controls.this]
  bucket     = aws_s3_bucket.this.id
  acl        = "private"
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
  count               = var.enable_kms && var.kms_key_id == null ? 1 : 0
  description         = "Key for bucket ${var.bucket_prefix}-${var.project}-${var.env}-${data.aws_region.this.region}"
  enable_key_rotation = true
  policy              = data.aws_iam_policy_document.key.json
  tags                = var.tags
}

# Only create an alias for the generated key
resource "aws_kms_alias" "this" {
  count         = var.enable_kms && var.kms_key_id == null ? 1 : 0
  name          = "alias/s3/${var.bucket_prefix}-${var.project}-${var.env}-${data.aws_region.this.region}"
  target_key_id = aws_kms_key.this[0].arn
}


