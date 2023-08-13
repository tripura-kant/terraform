terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.63.0" # Use the appropriate version
    }
  }
  backend "s3" {
    bucket = "mytkbucket-test"
    key    = "state/terraform.tfstate"
    region = "ap-southeast-2"
  }
}

provider "aws" {
  region = "ap-southeast-2"
}

data "template_file" "user_data" {
  template = file("${path.module}/userdata.sh")
  vars = {
    db_username      = var.database_user
    db_user_password = var.database_password
    db_name          = var.database_name
    db_RDS           = aws_db_instance.rds_instance.endpoint
  }
}

resource "aws_vpc" "prod_vpc" {
  cidr_block = "172.31.0.0/16"
}

resource "aws_subnet" "prod_subnet" {
  vpc_id     = aws_vpc.prod_vpc.id
  cidr_block = "172.31.0.0/24" # Replace with the desired subnet CIDR
}

resource "aws_security_group" "ec2_sg" {
  vpc_id = aws_vpc.prod_vpc.id

  // Allow SSH traffic from everywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "ec2_instance" {
  ami           = "ami-0a709bebf4fa9246f" # Replace with the latest Amazon Linux 2 AMI ID
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.prod_subnet.id
  security_groups = [aws_security_group.ec2_sg.id]
  associate_public_ip_address = true
}

resource "aws_security_group" "rds_sg" {
  vpc_id = aws_vpc.prod_vpc.id

  // Allow incoming traffic only from EC2 security group
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Update with specific CIDR blocks if needed
  }
}

resource "aws_subnet" "prod_subnet_a" {
  vpc_id     = aws_vpc.prod_vpc.id
  cidr_block = "172.31.1.0/24" # Replace with the desired subnet CIDR for AZ a
  availability_zone = "ap-southeast-2a"
}

resource "aws_subnet" "prod_subnet_b" {
  vpc_id     = aws_vpc.prod_vpc.id
  cidr_block = "172.31.2.0/24" # Replace with the desired subnet CIDR for AZ b
  availability_zone = "ap-southeast-2b"
}

resource "aws_db_subnet_group" "education" {
  name       = "my-rds-education-subnet-group"
  subnet_ids = [aws_subnet.prod_subnet_a.id, aws_subnet.prod_subnet_b.id]
}



resource "aws_db_instance" "rds_instance" {
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t2.micro"
  name                 = "wordpressdb"
  username             = "admin"
  password             = "password"
  parameter_group_name = "default.mysql5.7"
  skip_final_snapshot  = true

  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name  = aws_db_subnet_group.education.name
}

output "public_ip" {
  value = aws_instance.ec2_instance.public_ip
}
