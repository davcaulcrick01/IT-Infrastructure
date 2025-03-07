variable "ami_id" {
  description = "AMI ID for the EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "ssh_cidr_block" {
  description = "CIDR block allowed for SSH access"
  type        = string
  default     = "0.0.0.0/0" # Replace with a specific CIDR for production
}
