<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.14.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | 6.23.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.23.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_kms_alias.this](https://registry.terraform.io/providers/hashicorp/aws/6.23.0/docs/resources/kms_alias) | resource |
| [aws_kms_key.this](https://registry.terraform.io/providers/hashicorp/aws/6.23.0/docs/resources/kms_key) | resource |
| [aws_s3_bucket.this](https://registry.terraform.io/providers/hashicorp/aws/6.23.0/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_acl.s3_acl](https://registry.terraform.io/providers/hashicorp/aws/6.23.0/docs/resources/s3_bucket_acl) | resource |
| [aws_s3_bucket_lifecycle_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/6.23.0/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_metric.enable-metrics-bucket](https://registry.terraform.io/providers/hashicorp/aws/6.23.0/docs/resources/s3_bucket_metric) | resource |
| [aws_s3_bucket_ownership_controls.this](https://registry.terraform.io/providers/hashicorp/aws/6.23.0/docs/resources/s3_bucket_ownership_controls) | resource |
| [aws_s3_bucket_policy.this](https://registry.terraform.io/providers/hashicorp/aws/6.23.0/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.this](https://registry.terraform.io/providers/hashicorp/aws/6.23.0/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.this_aes256](https://registry.terraform.io/providers/hashicorp/aws/6.23.0/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.this_kms](https://registry.terraform.io/providers/hashicorp/aws/6.23.0/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.this](https://registry.terraform.io/providers/hashicorp/aws/6.23.0/docs/resources/s3_bucket_versioning) | resource |
| [aws_caller_identity.this](https://registry.terraform.io/providers/hashicorp/aws/6.23.0/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.s3_kms_policy](https://registry.terraform.io/providers/hashicorp/aws/6.23.0/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.this](https://registry.terraform.io/providers/hashicorp/aws/6.23.0/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_archive_retention_noncurrent_days"></a> [archive\_retention\_noncurrent\_days](#input\_archive\_retention\_noncurrent\_days) | archive retention non-concurrent days | `string` | `90` | no |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS Region | `string` | `"us-west-2"` | no |
| <a name="input_default_retention_noncurrent_days"></a> [default\_retention\_noncurrent\_days](#input\_default\_retention\_noncurrent\_days) | retention non-concurrent days | `string` | `180` | no |
| <a name="input_enable_kms"></a> [enable\_kms](#input\_enable\_kms) | Enable KMS-backed server-side encryption (aws:kms). If false, AES256 will be used. | `bool` | `false` | no |
| <a name="input_env"></a> [env](#input\_env) | value representing the environment (e.g., dev, staging, prod) | `string` | `"sbx"` | no |
| <a name="input_kms_key_id"></a> [kms\_key\_id](#input\_kms\_key\_id) | Optional KMS CMK ID or ARN to use for aws:kms encryption. If null, a new CMK will be created when `enable_kms` is true. | `string` | `null` | no |
| <a name="input_project"></a> [project](#input\_project) | Project name | `string` | `"json-to-csv-datapipeline"` | no |
| <a name="input_s3_name_prefix"></a> [s3\_name\_prefix](#input\_s3\_name\_prefix) | The name of the s3 bucket | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to be applied to created resources | `map(string)` | `{}` | no |
| <a name="input_versioning"></a> [versioning](#input\_versioning) | Bucket Versioning | `string` | `"Disabled"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_name"></a> [name](#output\_name) | Name of the created bucket |
| <a name="output_policy_json"></a> [policy\_json](#output\_policy\_json) | Required IAM policies |
| <a name="output_s3_bucket_arn"></a> [s3\_bucket\_arn](#output\_s3\_bucket\_arn) | s3 bucket arn |
| <a name="output_s3_bucket_domain_name"></a> [s3\_bucket\_domain\_name](#output\_s3\_bucket\_domain\_name) | s3 bucket domain name |
| <a name="output_s3_bucket_id"></a> [s3\_bucket\_id](#output\_s3\_bucket\_id) | s3 bucket id |
| <a name="output_s3_bucket_region"></a> [s3\_bucket\_region](#output\_s3\_bucket\_region) | s3 bucket region |
| <a name="output_s3_hosted_zone_id"></a> [s3\_hosted\_zone\_id](#output\_s3\_hosted\_zone\_id) | s3 hosted zone id |
<!-- END_TF_DOCS -->