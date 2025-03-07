# AWS Region
variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

# EC2 Instance AMI ID
variable "ami_id" {
  description = "AMI ID for the EC2 instance"
  type        = string
  default     = "ami-01816d07b1128cd2d"
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
  default     = "vpc-02e46df7df0b40433"
}

# EC2 Instance Type
variable "instance_type" {
  description = "Instance type for the EC2 instance"
  type        = string
  default     = "t2.micro"
}

# EC2 Instance Key Name
variable "key_name" {
  description = "Key name for the EC2 instance"
  type        = string
  default     = "car-rental-key.pem"
}

# EC2 Instance Name
variable "instance_name" {
  description = "Name of the EC2 instance"
  type        = string
}

# VPC and Subnet Details
variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
  default     = "Grey-VPC"
}

variable "subnet_name" {
  description = "Name of the private subnet in the VPC"
  type        = string
  default     = "Grey-private-subnet"
}

variable "subnet_id" {
  description = "The ID of the subnet to deploy the instance in (takes precedence over subnet_name)"
  type        = string
  default     = ""
}

variable "s3_acl" {
  description = "ACL for the S3 bucket"
  type        = string
  default     = "private"
}

variable "s3_force_destroy" {
  description = "Force destroy the S3 bucket (true for non-empty buckets)"
  type        = bool
  default     = false
}

# Common Tags
variable "common_tags" {
  description = "Common tags to be applied to all resources"
  type        = map(string)
}

variable "ecr_repo_url" {
  description = "ECR repository URL"
  type        = string
  default     = "522814698925.dkr.ecr.us-east-1.amazonaws.com/greyzone-intelligence"
}

variable "container_tag" {
  description = "Tag of the container image to pull"
  type        = string
  default     = "latest"
}

variable "postgres_port" {
  description = "Port for the application"
  type        = string
}

variable "tags" {
  description = "Tags for the resources"
  type        = map(string)
  default     = {}
}

variable "ssh_cidr_blocks" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = ["10.0.0.0/16"] # Restrict to your VPC or specific IPs
}

variable "db_cidr_blocks" {
  description = "CIDR blocks allowed for database access"
  type        = list(string)
  default     = ["10.0.0.0/16"] # Restrict to your VPC
}

variable "root_volume_size" {
  description = "Size of the root volume in GB"
  type        = number
  default     = 20
}

variable "data_volume_size" {
  description = "Size of the data volume in GB"
  type        = number
  default     = 100
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "production"
}

variable "db_username" {
  description = "Database admin username"
  type        = string
  default     = "dbadmin"
  sensitive   = true
}

variable "db_password" {
  description = "Database admin password"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "Name of the database to create"
  type        = string
  default     = "appdb"
}

variable "bucket_name" {
  description = "Name of the S3 bucket for database backups"
  type        = string
  default     = "grey-database"
}

variable "backup_retention_weeks" {
  description = "Number of weeks to retain database backups in S3"
  type        = number
  default     = 4
} 