resource "aws_s3_bucket" "backend_bucket" {
  bucket = var.backend_bucket
  # Additional configuration for the backend bucket, if needed
}
