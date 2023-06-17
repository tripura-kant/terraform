terraform {
  required_version = ">= 1.0.0"
}

module "backend" {
  source      = "./modules/backend"
  backend_bucket = var.bucket_name
}

module "dev" {
  source         = "./modules/dev"
  bucket_name = var.bucket_name
}

module "staging" {
  source         = "./modules/staging"
  bucket_name = var.bucket_name
}

module "production" {
  source         = "./modules/production"
  bucket_name = var.bucket_name
}
