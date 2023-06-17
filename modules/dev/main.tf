# Additional resources and configuration specific to the dev environment
resource "aws_s3_bucket" "backend_bucket" {
  bucket = var.bucket_name
  # Additional configuration for the backend bucket, if needed
}
