resource "aws_s3_bucket" "backend_bucket" {
  bucket = var.bucket_name
  # Additional configuration for the backend bucket, if needed
}
