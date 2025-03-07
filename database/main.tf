########################################
# EC2 Instance for Database
########################################
# Get subnet data from VPC
data "aws_subnet" "selected" {
  # Only perform lookup if subnet_id is not directly provided
  count = var.subnet_id == "" ? 1 : 0
  
  filter {
    name   = "tag:Name"
    values = [var.subnet_name]
  }
  vpc_id = var.vpc_id
}

resource "aws_instance" "database_instance" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = replace(var.key_name, ".pem", "") # Remove .pem extension from key name
  subnet_id                   = var.subnet_id != "" ? var.subnet_id : data.aws_subnet.selected[0].id
  vpc_security_group_ids      = [aws_security_group.database_sg.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.database_profile.name

  root_block_device {
    volume_type           = "gp2"
    volume_size           = var.root_volume_size
    delete_on_termination = true
    encrypted             = true
  }

  # EBS volume for database data
  ebs_block_device {
    device_name           = "/dev/sdf"
    volume_type           = "gp2"
    volume_size           = var.data_volume_size
    delete_on_termination = true
    encrypted             = true
  }

  # User data script installs and configures PostgreSQL
  user_data = file("${path.module}/scripts/userdata.sh")

  tags = {
    Name        = "${local.name_prefix}-Database-Instance"
    Environment = var.environment
    Role        = "Database"
  }
}

########################################
# Security Group for Database
########################################
resource "aws_security_group" "database_sg" {
  name        = "${local.name_prefix}-database-sg"
  description = "Security group for database instance"
  vpc_id      = var.vpc_id

  # SSH access - Allow from anywhere for initial setup
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # <-- Change this to allow SSH from anywhere temporarily
    description = "SSH access"
  }

  # Database port access (PostgreSQL) - Allow from specific IPs
  ingress {
    from_port   = 5432
    to_port     = 5439
    protocol    = "tcp"
    cidr_blocks = var.db_cidr_blocks
    description = "PostgreSQL access"
  }

  # Database port access (MySQL/MariaDB)
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = var.db_cidr_blocks
    description = "MySQL/MariaDB access"
  }

  # Outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "${local.name_prefix}-Database-SG"
    Environment = var.environment
  }
}

########################################
# IAM Role and Instance Profile
########################################
resource "aws_iam_role" "database_role" {
  name = "${local.name_prefix}-database-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${local.name_prefix}-Database-Role"
    Environment = var.environment
  }
}

resource "aws_iam_instance_profile" "database_profile" {
  name = "${local.name_prefix}-database-profile"
  role = aws_iam_role.database_role.name
}

resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.database_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "s3_backup_policy" {
  name = "${local.name_prefix}-s3-backup-policy"
  role = aws_iam_role.database_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ]
        Effect   = "Allow"
        Resource = [
          "arn:aws:s3:::${var.bucket_name}",
          "arn:aws:s3:::${var.bucket_name}/*"
        ]
      }
    ]
  })
} 