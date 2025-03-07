########################################
# Locals for Database Configuration
########################################
locals {
  name_prefix = "Grey"
  
  # Database configuration
  db_port     = 5432 # PostgreSQL default port
  db_engine   = "postgresql"
  
  # Backup configuration
  backup_retention_days = 7
  backup_window         = "03:00-04:00" # UTC time
  
  # Tags
  common_tags = {
    Project     = "Grey"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
} 