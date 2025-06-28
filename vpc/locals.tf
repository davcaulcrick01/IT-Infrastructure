########################################
# Locals for Region, CIDRs, and Naming
########################################
locals {
  # AWS Region where resources will be created
  region = "us-east-1"

  # CIDR blocks
  reason_vpc_cidr      = "10.0.0.0/16"
  reason_public_cidr   = "10.0.1.0/24"
  reason_private_cidr  = "10.0.2.0/24"
  reason_private2_cidr = "10.0.4.0/24" # New second private subnet - changed to avoid conflict

  # A simple name prefix for tags
  name_prefix = "Grey"

  # Availability Zones for subnets
  public_az   = "us-east-1a"
  private_az  = "us-east-1a"
  private2_az = "us-east-1b" # Second private subnet in different AZ

}