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

data "aws_availability_zones" "available" {
  state = "available"
}

data "template_file" "userdata" {
  template = file("${path.module}/userdata.sh")
  vars = {
    db_username      = var.db_username
    db_user_password = var.db_password
    db_name          = var.db_name
    db_RDS           = aws_db_instance.prod_database.address
  }
}

data "aws_ami" "linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

// Create a VPC
resource "aws_vpc" "prod_vpc" {
  cidr_block = var.vpc_cidr_block
  // We want DNS hostnames enabled for this VPC
  enable_dns_hostnames = true

  // We are tagging the VPC with the name "prod_vpc"
  tags = {
    Name = "prod_vpc"
  }
}

resource "aws_internet_gateway" "prod_igw" {
  vpc_id = aws_vpc.prod_vpc.id

  // We are tagging the IGW with the name prod_igw
  tags = {
    Name = "prod_igw"
  }
}

// Create a group of public subnets based on the variable subnet_count.public
resource "aws_subnet" "prod_public_subnet" {
  // count is the number of resources we want to create
  // here we are referencing the subnet_count.public variable which
  // current assigned to 1 so only 1 public subnet will be created
  count = var.subnet_count.public

  // Put the subnet into the "prod_vpc" VPC
  vpc_id = aws_vpc.prod_vpc.id

  cidr_block = var.public_subnet_cidr_blocks[count.index]

  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "prod_public_subnet_${count.index}"
  }
}

// Create a group of private subnets based on the variable subnet_count.private
resource "aws_subnet" "private_private_subnet" {
  count = var.subnet_count.private

  vpc_id = aws_vpc.prod_vpc.id

  // We are grabbing a CIDR block from the "private_subnet_cidr_blocks" variable
  // since it is a list, we need to grab the element based on count,
  // since count is 2, the first subnet will grab the CIDR block 10.0.101.0/24
  // and the second subnet will grab the CIDR block 10.0.102.0/24
  cidr_block = var.private_subnet_cidr_blocks[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  
  tags = {
    Name = "prod_private_subnet_${count.index}"
  }
}

// Create a public route table named "prod_public_rt"
resource "aws_route_table" "prod_public_rt" {
  // Put the route table in the "prod_vpc" VPC
  vpc_id = aws_vpc.prod_vpc.id


  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.prod_igw.id
  }
}

// Here we are going to add the public subnets to the 
// "prod_public_rt" route table
resource "aws_route_table_association" "public" {
  count = var.subnet_count.public
  route_table_id = aws_route_table.prod_public_rt.id
  subnet_id = aws_subnet.prod_public_subnet[count.index].id
}

resource "aws_route_table" "prod_private_rt" {

  vpc_id = aws_vpc.prod_vpc.id
}

resource "aws_route_table_association" "private" {
  count = var.subnet_count.private
  route_table_id = aws_route_table.prod_private_rt.id
  subnet_id = aws_subnet.prod_private_subnet[count.index].id
}

// Create a security for the EC2 instances called "prod_web_sg"
resource "aws_security_group" "prod_web_sg" {
  // Basic details like the name and description of the SG
  name        = "prod_web_sg"
  description = "Security group for prod web servers"
  // We want the SG to be in the "prod_vpc" VPC
  vpc_id = aws_vpc.prod_vpc.id
  ingress {
    description = "Allow all traffic through HTTP"
    from_port   = "80"
    to_port     = "80"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow SSH from my computer"
    from_port   = "22"
    to_port     = "22"
    protocol    = "tcp"
    // This is using the variable "my_ip"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  // Here we are tagging the SG with the name "prod_web_sg"
  tags = {
    Name = "prod_web_sg"
  }
}


resource "aws_security_group" "prod_db_sg" {
  name        = "prod_db_sg"
  description = "Security group for prod databases"
  vpc_id = aws_vpc.prod_vpc.id
  ingress {
    description     = "Allow MySQL traffic from only the web sg"
    from_port       = "3306"
    to_port         = "3306"
    protocol        = "tcp"
    security_groups = [aws_security_group.prod_web_sg.id]
  }

  tags = {
    Name = "prod_db_sg"
  }
}

// Create a db subnet group named "prod_db_subnet_group"
resource "aws_db_subnet_group" "prod_db_subnet_group" {
  // The name and description of the db subnet group
  name        = "prod_db_subnet_group"
  description = "DB subnet group for prod"

  subnet_ids = [for subnet in aws_subnet.prod_private_subnet : subnet.id]
}

// Create a DB instance called "prod_database"
resource "aws_db_instance" "prod_database" {
  allocated_storage = var.settings.database.allocated_storage
  engine = var.settings.database.engine
  engine_version = var.settings.database.engine_version
  instance_class = var.settings.database.instance_class
  #db_name = var.settings.database.db_name

  // The master user of our database. This is being set by the
  // db_username variable, which is being declared in our secrets file
  username = var.db_username

  // The password for the master user. This is being set by the 
  // db_username variable, which is being declared in our secrets file
  password = var.db_password

  // This is the DB subnet group "prod_db_subnet_group"
  db_subnet_group_name = aws_db_subnet_group.prod_db_subnet_group.id

  // This is the security group for the database. It takes a list, but since
  // we only have 1 security group for our db, we are just passing in the
  // "prod_db_sg" security group
  vpc_security_group_ids = [aws_security_group.prod_db_sg.id]

  // This refers to the skipping final snapshot of the database. It is a 
  // boolean that is set by the settings.database.skip_final_snapshot
  // variable, which is currently set to true.
  skip_final_snapshot = var.settings.database.skip_final_snapshot
}

// Create a key pair named "prod_kp"
resource "aws_key_pair" "prod_kp" {
  // Give the key pair a name
  key_name = "prod_kp"

  // This is going to be the public key of our
  // ssh key. The file directive grabs the file
  // from a specific path. Since the public key
  // was created in the same directory as main.tf
  // we can just put the name
  public_key = file("./test-key.pub")
}

// Create an EC2 instance named "prod_web"
resource "aws_instance" "prod_web" {
  // count is the number of instance we want
  // since the variable settings.web_app.cont is set to 1, we will only get 1 EC2
  count = var.settings.web_app.count
  ami = data.aws_ami.linux.id
  key_name      = "terraform-key"

  // This is the instance type of the EC2 instance. The variable
  // settings.web_app.instance_type is set to "t2.micro"
  instance_type = var.settings.web_app.instance_type
  subnet_id = aws_subnet.prod_public_subnet[count.index].id
  user_data = data.template_file.userdata.rendered

  // The security groups of the EC2 instance. This takes a list, however we only
  // have 1 security group for the EC2 instances.
  vpc_security_group_ids = [aws_security_group.prod_web_sg.id]

  // We are tagging the EC2 instance with the name "prod_db_" followed by
  // the count index
  tags = {
    Name = "prod_web_${count.index}"
  }
}

// Create an Elastic IP named "prod_web_eip" for each
// EC2 instance
resource "aws_eip" "prod_web_eip" {
  // count is the number of Elastic IPs to create. It is
  // being set to the variable settings.web_app.count which
  // refers to the number of EC2 instances. We want an
  // Elastic IP for every EC2 instance
  count = var.settings.web_app.count

  // The EC2 instance. Since prod_web is a list of 
  // EC2 instances, we need to grab the instance by the 
  // count index. Since the count is set to 1, it is
  // going to grab the first and only EC2 instance
  instance = aws_instance.prod_web[count.index].id

  // We want the Elastic IP to be in the VPC
  vpc = true

  // Here we are tagging the Elastic IP with the name
  // "prod_web_eip_" followed by the count index
  tags = {
    Name = "prod_web_eip_${count.index}"
  }
}
