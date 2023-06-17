Edit the values of these files

production.tfvars
staging.tfvars
dev.tfvars

example like this

bucket_name = "staging-backend-bucket-name22"

then run

terraform init
terraform plan
terraform apply 