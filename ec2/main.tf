########################################
# EC2 Instance
########################################
resource "aws_instance" "grey_instance" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.grey_private.id
  associate_public_ip_address = false

  tags = {
    Name = "${local.name_prefix}-EC2-Instance"
  }
}

########################################
# Security Group
########################################
resource "aws_security_group" "ec2_sg" {
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Replace with a specific CIDR for production
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-EC2-SG"
  }
}
