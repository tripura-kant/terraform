#https://github.com/lkravi/kube8aws.git

#!/bin/bash

yum install git -y
# Update the system
sudo yum update -y

# Install EPEL repository for Ansible
sudo amazon-linux-extras install epel -y

# Install Ansible
sudo yum install ansible -y

# Verify Ansible installation
ansible --version

# Install yum-config-manager to manage repository configurations
sudo yum install -y yum-utils

# Add the HashiCorp Linux repository for Terraform
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo

# Install Terraform
sudo yum install terraform -y

# Verify Terraform installation
terraform --version

echo "Ansible and Terraform installation complete."

 git clone https://github.com/lkravi/kube8aws.git

  cd kube8aws/


  terraform init; terraform plan; terraform apply
