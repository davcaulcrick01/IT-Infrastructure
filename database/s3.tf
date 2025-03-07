# Provider configuration for S3 resources
provider "aws" {
  alias  = "eu_west_2"
  region = "eu-west-2"
}

# S3 bucket for database backups
resource "aws_s3_bucket" "database_backup_bucket" {
  provider      = aws.eu_west_2
  bucket        = var.bucket_name
  force_destroy = var.s3_force_destroy

  tags = {
    Name        = var.bucket_name
    Environment = var.environment
  }
}

# Enable versioning for the backup bucket
resource "aws_s3_bucket_versioning" "database_backups_versioning" {
  provider = aws.eu_west_2
  bucket   = aws_s3_bucket.database_backup_bucket.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# Configure lifecycle rules for the backup bucket
resource "aws_s3_bucket_lifecycle_configuration" "backup_lifecycle" {
  provider = aws.eu_west_2
  bucket   = aws_s3_bucket.database_backup_bucket.id

  rule {
    id     = "database-backups-cleanup"
    status = "Enabled"

    # Transition to cheaper storage after 30 days
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    
    # Ensure expiration is greater than transition days
    expiration {
      days = 60  # Fixed value that is greater than transition days (30)
    }
  }
}

# Block public access to the backup bucket
resource "aws_s3_bucket_public_access_block" "database_bucket_access" {
  provider = aws.eu_west_2
  bucket   = aws_s3_bucket.database_backup_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable server-side encryption for the backup bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "database_backups_encryption" {
  provider = aws.eu_west_2
  bucket   = aws_s3_bucket.database_backup_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}