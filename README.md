Terraform S3 Bucket
This Terraform module will create a secure S3 bucket suitable for application blob storage. Each bucket is encrypted with a unique KMS key. Bucket and key policies are set to allow access only by the configured principals. Public access blocks are enabled to prevent anything in the bucket from accidentally becoming public.

Example:

module "bucket" {
  source = "github.com/thoughtbot/terraform-s3-bucket?ref=v0.2.0"

  name            = "my-unique-bucket-name"
  trust_principal = aws_iam_role.myservice.arn
}
The outputs include policy_json, which you can attach to an IAM policy or role to permit reading and writing the bucket.

Requirements
Name	Version
terraform	>= 0.14.0
aws	~> 5.0
Providers
Name	Version
aws	~> 5.0
Modules
No modules.

Resources
Name	Type
aws_kms_alias.this	resource
aws_kms_key.this	resource
aws_s3_bucket.this	resource
aws_s3_bucket_policy.this	resource
aws_s3_bucket_public_access_block.this	resource
aws_s3_bucket_server_side_encryption_configuration.this	resource
aws_s3_bucket_versioning.this	resource
aws_caller_identity.this	data source
aws_iam_policy_document.bucket	data source
aws_iam_policy_document.key	data source
aws_iam_policy_document.this	data source
aws_region.this	data source
Inputs
Name	Description	Type	Default	Required
bucket_policy	Override the resource policy on the bucket	string	null	no
name	The name of the s3 bucket	string	n/a	yes
read_principals	Principal allowed to read from the bucket (default: current account)	list(string)	[]	no
read_tags	Tags required on principals reading to the bucket	map(string)	{}	no
readwrite_principals	Principal allowed to read and write to the bucket (default: current account)	list(string)	[]	no
readwrite_tags	Tags required on principals writing to the bucket	map(string)	{}	no
tags	Tags to be applied to created resources	map(string)	{}	no
Outputs
Name	Description
name	Name of the created bucket
policy_json	Required IAM policies
Development
Please see CONTRIBUTING.md.
