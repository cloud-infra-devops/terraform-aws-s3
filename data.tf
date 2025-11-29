data "aws_caller_identity" "this" {}
data "aws_region" "this" {}

locals {
  # Determine the KMS key id to use: prefer provided `var.kms_key_id`, otherwise use created key when present
  kms_master_key_id = var.kms_key_id != null ? var.kms_key_id : (length(aws_kms_key.this) > 0 ? aws_kms_key.this[0].arn : null)
  account_id        = data.aws_caller_identity.this.account_id
  account_arn       = "arn:aws:iam::${local.account_id}:root"
  region            = data.aws_region.this.region
  # bucket_arn        = "arn:aws:s3:::${var.s3_name_prefix}-${var.project}-${var.env}-${data.aws_region.this.region}"
  # sid_suffix           = join("", regexall("[[:alnum:]]+", var.bucket_prefix))
  # read_principals      = concat(var.read_principals, local.readwrite_principals)
  # readwrite_principals = coalescelist(var.readwrite_principals, [local.account_arn])
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

data "aws_iam_policy_document" "s3_kms_policy" {
  version = "2012-10-17"
  statement {
    sid    = "Enable IAM User Permissions"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id}:root"]
    }
    actions = [
      "kms:*"
    ]
    resources = ["*"]
  }
  statement {
    sid    = "Allow S3 to use the key"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
    actions = [
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
    resources = ["*"]
  }
}
/*
data "aws_iam_policy_document" "key" {
  statement {
    sid = "AllowManagement"
    not_actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*"
    ]
    resources = ["*"]
    principals {
      identifiers = [local.account_arn]
      type        = "AWS"
    }
  }

  statement {
    sid = "AllowS3"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*"
    ]
    resources = ["*"]
    principals {
      identifiers = [local.account_arn]
      type        = "AWS"
    }
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["s3.${local.region}.amazonaws.com"]
    }
  }

  statement {
    sid    = "DenyDirectDecryption"
    effect = "Deny"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*"
    ]
    resources = ["*"]
    principals {
      identifiers = ["*"]
      type        = "AWS"
    }
    condition {
      test     = "StringNotEquals"
      variable = "kms:ViaService"
      values   = ["s3.${local.region}.amazonaws.com"]
    }
  }
}

    sid    = "AllowManagement"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [local.account_arn]
    }
    resources = [local.bucket_arn, "${local.bucket_arn}/*"]
    not_actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]
  }
  statement {
    sid       = "AllowWrite"
    effect    = "Allow"
    resources = [local.bucket_arn, "${local.bucket_arn}/*"]
    actions = [
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    principals {
      type        = "AWS"
      identifiers = local.readwrite_principals
    }
    dynamic "condition" {
      for_each = var.readwrite_tags

      content {
        test     = "StringEquals"
        variable = "aws:PrincipalTag/${condition.key}"
        values   = [condition.value]
      }
    }
  }

  statement {
    sid       = "AllowRead"
    effect    = "Allow"
    resources = [local.bucket_arn, "${local.bucket_arn}/*"]
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]
    principals {
      type        = "AWS"
      identifiers = local.read_principals
    }
    dynamic "condition" {
      for_each = var.read_tags
      content {
        test     = "StringEquals"
        variable = "aws:PrincipalTag/${condition.key}"
        values   = [condition.value]
      }
    }
  }

  statement {
    sid       = "RequireObjectEncryption"
    effect    = "Deny"
    actions   = ["s3:PutObject"]
    resources = ["${local.bucket_arn}/*"]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    # If KMS-backed SSE is enabled, require KMS key id in the request; otherwise require AES256
    dynamic "condition" {
      for_each = var.enable_kms ? [1] : []
      content {
        test     = "StringNotEquals"
        variable = "s3:x-amz-server-side-encryption-aws-kms-key-id"
        values   = [var.kms_key_id != null ? var.kms_key_id : aws_kms_key.this[0].arn]
      }
    }

    dynamic "condition" {
      for_each = var.enable_kms ? [] : [1]
      content {
        test     = "StringNotEquals"
        variable = "s3:x-amz-server-side-encryption"
        values   = ["AES256"]
      }
    }
  }
}

data "aws_iam_policy_document" "this" {
  statement {
    sid = "ReadWrite${local.sid_suffix}"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject"
    ]
    resources = [
      "${aws_s3_bucket.this.arn}/*",
    ]
  }

  statement {
    sid = "List${local.sid_suffix}"
    actions = [
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.this.arn
    ]
  }

  # Only add decrypt policy when KMS is enabled (avoid referencing a non-existent key)
  dynamic "statement" {
    for_each = var.enable_kms ? [1] : []
    content {
      sid = "Decrypt${local.sid_suffix}"
      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*"
      ]
      resources = [
        var.kms_key_id != null ? var.kms_key_id : aws_kms_key.this[0].arn
      ]
    }
  }
}
*/
