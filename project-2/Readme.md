there are 3 files

main.tf contains all the terraform code
userdata.sh contains the userscript
variables.tf contains all variables used in terraform code



##### Terraform code to create ec2, rds 

The requirements are: 
	•	Setup a S3 backend for terraform. Follow the process describe on this link:
	•	Terraform S3 Backend Best Practices 
	•	The EC2 instance should always use the latest amazon 2 Linux ami
	•	Everything should be done in the prod VPC
	•	EC2 should allow SSH traffic from everywhere
	•	Ec2 and RDS connectivity
	•	The RDS security group should only allow communication from the EC2 SG
	•	The output of the terraform deployment should be the public IP of the instance.
	•	I have a user data script that is ready to use.
	•	I am new to Terraform and currently am working on the cloud formation template that I mentioned 
