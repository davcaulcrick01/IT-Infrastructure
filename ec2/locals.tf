########################################
# Locals for EC2 Configuration
########################################
locals {
  ec2_name_prefix = "Reason-EC2"
  ami_id          = var.ami_id
  instance_type   = var.instance_type
  ssh_cidr_block  = var.ssh_cidr_block

  # A simple name prefix for tags
  name_prefix = "Grey"
}