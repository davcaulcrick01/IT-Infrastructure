# EC2 Instance Configuration
ami_id           = "ami-01816d07b1128cd2d"
instance_type    = "t2.medium"
instance_name    = "database-instance"
key_name         = "car-rental-key"
region           = "us-east-1"

# Volume Configuration
root_volume_size = 20
data_volume_size = 100

# Network Configuration
vpc_name         = "Grey-VPC"
vpc_id           = "vpc-02e46df7df0b40433"  # From your state file
subnet_id        = "subnet-07f2856bac440c10e"  # Public subnet ID
subnet_name      = "Grey-public-subnet"  # Keep this for reference
ssh_cidr_blocks  = ["0.0.0.0/0"]
db_cidr_blocks   = ["0.0.0.0/0"]

# Database Configuration
environment      = "production"
db_username      = "dbadmin"
db_password      = "StrongPassword123!" # Change this and use AWS Secrets Manager in production
db_name          = "caulcrick_properties"
postgres_port    = "5434"  # Using a different port from other databases

# Backup Configuration
bucket_name            = "grey-database-bucket"
backup_retention_weeks = 4

# Common Tags
common_tags = {
  Project = "GreyzoneIntelligence"
  Owner   = "TeamGreyZone"
}