module "s3-bucket" {
  source      = "./s3"
  bucket_name = var.bucket_name
}

