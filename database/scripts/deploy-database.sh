#!/bin/bash

# This script helps deploy different database configurations
# Usage: ./deploy-database.sh <app_name> [--manual]

# Check if environment argument is provided
if [ -z "$1" ]; then
  echo "Usage: ./deploy-database.sh <app_name> [--manual]"
  echo "Options:"
  echo "  --manual    Disable automatic deployment and just show commands"
  echo "Available apps: car_rental, greyzone_intelligence, etc."
  exit 1
fi

APP_NAME="$1"
AUTO_DEPLOY=true  # Auto-deploy is now the DEFAULT behavior

# Check for manual flag (reverses the logic)
if [ "$2" = "--manual" ]; then
  AUTO_DEPLOY=false
  echo "Manual mode enabled. The script will only show commands without executing them."
fi

TFVARS_FILE="${APP_NAME}.tfvars"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
REPO_DIR="$(cd "$PARENT_DIR/../.." && pwd)"

# Enable debugging to see what's happening
set -x

# Get the key content from environment variable and create a temporary key file
KEY_VAR_NAME="CAR_RENTAL_KEY"
KEY_CONTENT="${!KEY_VAR_NAME}"
KEY_FILE=""

if [ -n "$KEY_CONTENT" ]; then
  KEY_FILE="/tmp/car-rental-key.pem"
  echo "$KEY_CONTENT" > "$KEY_FILE"
  chmod 600 "$KEY_FILE"
  echo "Created temporary key file at $KEY_FILE"
fi

echo "Script directory: $SCRIPT_DIR"
echo "Parent directory: $PARENT_DIR"

# Navigate to the parent directory where Terraform files are located
cd "$PARENT_DIR" || { echo "Error: Could not navigate to Terraform directory"; exit 1; }

# Check if tfvars file exists
if [ ! -f "$TFVARS_FILE" ]; then
  # Try with _terraform suffix
  TFVARS_FILE="${APP_NAME}_terraform.tfvars"
  if [ ! -f "$TFVARS_FILE" ]; then
    echo "Error: Terraform variable file not found for $APP_NAME!"
    echo "Tried: ${APP_NAME}.tfvars and ${APP_NAME}_terraform.tfvars"
    exit 1
  fi
fi

echo "Deploying infrastructure for $APP_NAME using $TFVARS_FILE..."
echo "This will update the following files:"
echo "- main.tf: EC2 instance, security group, and IAM role configurations"
echo "- s3.tf: S3 bucket for database backups"
echo "- provider.tf: AWS provider configuration"

# Check for AWS credentials
if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
  echo "Warning: AWS credentials not found in environment variables."
  echo "Checking AWS CLI configuration..."
  
  if ! aws sts get-caller-identity &>/dev/null; then
    echo "Error: AWS credentials not properly configured."
    echo "Please configure AWS credentials using one of the following methods:"
    echo "1. Set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables"
    echo "2. Run 'aws configure' to set up credentials"
    echo "3. Use an EC2 instance with an appropriate IAM role"
    exit 1
  else
    echo "AWS credentials found in AWS CLI configuration."
  fi
fi

# Initialize Terraform
echo "Initializing Terraform..."
terraform init

# List local files before proceeding
echo "Local files in the current directory:"
ls -la

# Try to apply terraform to create/update resources
echo "Running terraform apply..."
terraform apply -var-file="$TFVARS_FILE" -auto-approve

# Try multiple methods to get the EC2 instance private IP address
EC2_PRIVATE_IP=""
EC2_PUBLIC_IP=""

# Method 1: Direct output from terraform for private and public IPs
echo "Trying to get IPs from terraform outputs..."
terraform output -raw instance_private_ip 2>/dev/null || echo "No 'instance_private_ip' output found"
terraform output -raw private_ip 2>/dev/null || echo "No 'private_ip' output found"
terraform output -raw instance_public_ip 2>/dev/null || echo "No 'instance_public_ip' output found"
terraform output -raw public_ip 2>/dev/null || echo "No 'public_ip' output found"

# Method 2: Get from terraform state
echo "Trying to get IPs from terraform state..."
INSTANCE_ID=$(terraform state show aws_instance.database_instance 2>/dev/null | grep "id" | head -1 | cut -d "=" -f2 | tr -d ' "')
echo "Instance ID from terraform state: $INSTANCE_ID"

if [ -n "$INSTANCE_ID" ]; then
  # Method 3: Get from AWS CLI using instance ID
  echo "Trying to get IPs from AWS CLI..."
  EC2_PRIVATE_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query "Reservations[0].Instances[0].PrivateIpAddress" --output text 2>/dev/null)
  echo "Private IP from AWS CLI: $EC2_PRIVATE_IP"
  
  EC2_PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --query "Reservations[0].Instances[0].PublicIpAddress" --output text 2>/dev/null)
  echo "Public IP from AWS CLI: $EC2_PUBLIC_IP"
fi

# If we still don't have private IP, try to parse it directly from the terraform state
if [ -z "$EC2_PRIVATE_IP" ]; then
  echo "Trying to parse private IP directly from terraform state..."
  EC2_PRIVATE_IP=$(terraform state show aws_instance.database_instance 2>/dev/null | grep -E "private_ip\s+" | head -1 | cut -d "=" -f2 | tr -d ' "')
  echo "Private IP parsed from terraform state: $EC2_PRIVATE_IP"
fi

# If we still don't have public IP, try to parse it directly from the terraform state
if [ -z "$EC2_PUBLIC_IP" ]; then
  echo "Trying to parse public IP directly from terraform state..."
  EC2_PUBLIC_IP=$(terraform state show aws_instance.database_instance 2>/dev/null | grep -E "public_ip\s+" | head -1 | cut -d "=" -f2 | tr -d ' "')
  echo "Public IP parsed from terraform state: $EC2_PUBLIC_IP"
fi

# Finally, if all else fails, try outputs again just in case
if [ -z "$EC2_PRIVATE_IP" ]; then
  # Try all possible output formats for private IP
  EC2_PRIVATE_IP=$(terraform output -json 2>/dev/null | grep -oE '"(instance_private_ip|private_ip)": "[0-9\.]+"' | head -1 | cut -d'"' -f4)
  echo "Private IP from JSON parsing: $EC2_PRIVATE_IP"
fi

if [ -z "$EC2_PUBLIC_IP" ]; then
  # Try all possible output formats for public IP
  EC2_PUBLIC_IP=$(terraform output -json 2>/dev/null | grep -oE '"(instance_public_ip|public_ip)": "[0-9\.]+"' | head -1 | cut -d'"' -f4)
  echo "Public IP from JSON parsing: $EC2_PUBLIC_IP"
fi

# Better extraction that handles inline comments
extract_var() {
  local var_name="$1"
  local file="$2"
  grep "$var_name" "$file" | cut -d '=' -f2 | cut -d '#' -f1 | tr -d ' "'
}

# Extract database variables from tfvars file
DB_NAME=$(extract_var 'db_name' "$TFVARS_FILE")
DB_USER=$(extract_var 'db_username' "$TFVARS_FILE")
DB_PORT=$(extract_var 'postgres_port' "$TFVARS_FILE")
DB_PASSWORD=$(extract_var 'db_password' "$TFVARS_FILE")

echo ""
echo "Deployment completed successfully!"
echo ""

# Run troubleshooting script if we have an instance ID
if [ -n "$INSTANCE_ID" ]; then
  echo "Running troubleshooting for instance $INSTANCE_ID..."
  chmod +x "$SCRIPT_DIR/troubleshoot-ec2.sh"
  "$SCRIPT_DIR/troubleshoot-ec2.sh" "$INSTANCE_ID"
fi

echo "IMPORTANT: You need to configure PostgreSQL on the EC2 instance."
echo ""

# Determine which IP to use (public preferred, private as fallback)
CONNECT_IP=""

# Check if public IP is available and valid
if [[ -n "$EC2_PUBLIC_IP" && "$EC2_PUBLIC_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ && "$EC2_PUBLIC_IP" != "None" ]]; then
  echo "Successfully retrieved EC2 public IP: $EC2_PUBLIC_IP"
  CONNECT_IP="$EC2_PUBLIC_IP"
  echo "Using public IP for connection (accessible from anywhere)"
# Otherwise check if private IP is available and valid
elif [[ -n "$EC2_PRIVATE_IP" && "$EC2_PRIVATE_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Successfully retrieved EC2 private IP: $EC2_PRIVATE_IP"
  CONNECT_IP="$EC2_PRIVATE_IP"
  echo "Using private IP for connection (requires VPN or being in the same VPC)"
else
  echo "WARNING: Could not retrieve a valid EC2 instance IP address!"
  echo "You'll need to find the IP in the AWS Console and use it in the commands below."
  CONNECT_IP="YOUR_INSTANCE_IP"
  AUTO_DEPLOY=false  # Disable auto-deploy if we can't get the IP
fi

# Determine connection command and SSH key
CONNECTION_SSH_KEY=""
if [ -n "$KEY_FILE" ]; then
  CONNECTION_SSH_KEY="$KEY_FILE"
else
  # Try to find an appropriate key file
  for default_key in ~/.ssh/id_rsa ~/.ssh/id_ed25519 ~/.ssh/car-rental-key.pem; do
    if [ -f "$default_key" ]; then
      CONNECTION_SSH_KEY="$default_key"
      break
    fi
  done
  
  if [ -z "$CONNECTION_SSH_KEY" ]; then
    CONNECTION_SSH_KEY="your-key.pem"
    AUTO_DEPLOY=false  # Disable auto-deploy if we can't find a key
  fi
fi

# Determine connection command
CONNECTION_CMD=""
if [[ "$CONNECT_IP" != "YOUR_INSTANCE_IP" ]]; then
  if [ -n "$KEY_FILE" ]; then
    CONNECTION_CMD="ssh -i $KEY_FILE ec2-user@$CONNECT_IP"
  else
    CONNECTION_CMD="ssh -i $CONNECTION_SSH_KEY ec2-user@$CONNECT_IP"
  fi
  echo "Connect to the EC2 instance:"
  echo "$CONNECTION_CMD"
else
  CONNECTION_CMD="ssh -i $CONNECTION_SSH_KEY ec2-user@YOUR_INSTANCE_IP"
  AUTO_DEPLOY=false  # Disable auto-deploy if we don't have a valid IP
fi

# Function to run a command on the EC2 instance
run_ssh_command() {
  local command="$1"
  echo "Running: $command"
  if [ "$CONNECTION_SSH_KEY" = "your-key.pem" ]; then
    echo "Cannot execute command: SSH key not specified"
    return 1
  fi
  ssh -i "$CONNECTION_SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=10 ec2-user@"$CONNECT_IP" "$command"
  return $?
}

# Function to copy a file to the EC2 instance
copy_file_to_instance() {
  local src="$1"
  local dest="$2"
  echo "Copying $src to $dest"
  if [ "$CONNECTION_SSH_KEY" = "your-key.pem" ]; then
    echo "Cannot copy file: SSH key not specified"
    return 1
  fi
  scp -i "$CONNECTION_SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$src" ec2-user@"$CONNECT_IP":"$dest"
  return $?
}

# Always display the commands (even if we're going to auto-execute them)
echo ""
echo "After connecting to the instance, run the following commands:"
echo ""
echo "# Copy the update-postgres.sh script to the instance (if not already there)"
if [ -n "$KEY_FILE" ]; then
  echo "scp -i $KEY_FILE $SCRIPT_DIR/update-postgres.sh ec2-user@$CONNECT_IP:/home/ec2-user/"
else
  echo "scp -i $CONNECTION_SSH_KEY $SCRIPT_DIR/update-postgres.sh ec2-user@$CONNECT_IP:/home/ec2-user/"
fi
echo ""
echo "# Make the script executable"
echo "${CONNECTION_CMD} 'chmod +x /home/ec2-user/update-postgres.sh'"
echo ""
echo "# Run the script to set up PostgreSQL"
echo "${CONNECTION_CMD} 'db_username=\"$DB_USER\" db_password=\"$DB_PASSWORD\" db_name=\"$DB_NAME\" postgres_port=\"$DB_PORT\" /home/ec2-user/update-postgres.sh start'"
echo ""
echo "# View the logs of the update-postgres.sh script"
echo "${CONNECTION_CMD} 'cat /var/log/postgres-update-${DB_NAME}.log'"
echo ""
echo "To connect to the PostgreSQL database after setup:"
echo "psql -h $CONNECT_IP -U $DB_USER -d $DB_NAME -p $DB_PORT"

# Automatically execute commands if auto-deploy is enabled
if [ "$AUTO_DEPLOY" = true ]; then
  echo ""
  echo "Auto-deploy is enabled. Executing commands automatically..."
  echo ""
  
  # Modify the SSH connection loop with better diagnostics and potential to skip
  echo "Waiting for instance to be ready for SSH connections..."

  # Add a way to skip waiting if you already know the instance is ready
  if [ -n "$SKIP_SSH_WAIT" ]; then
    echo "SKIP_SSH_WAIT is set, skipping the SSH availability check"
  else
    # Try connecting with more verbose output
    for i in {1..10}; do  # Reduced from 30 to 10 attempts
      echo "Attempt $i/10 - checking SSH connection..."
      
      # More verbose SSH attempt to see what's failing
      if ssh -v -i "$CONNECTION_SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o BatchMode=yes ec2-user@"$CONNECT_IP" echo "SSH connection successful" &>/tmp/ssh_test_output; then
        echo "Instance is ready for SSH connections"
        break
      else
        # Show the SSH error for debugging
        echo "SSH connection failed. Error output:"
        cat /tmp/ssh_test_output
        
        # Check if we can ping the instance
        echo "Trying to ping the instance..."
        ping -c 1 "$CONNECT_IP" || echo "Ping failed"
        
        # Check if this is the last attempt
        if [ $i -eq 10 ]; then
          echo "Instance not ready after 10 attempts."
          echo "You can try manually connecting with: ssh -i $CONNECTION_SSH_KEY ec2-user@$CONNECT_IP"
          echo "If you can connect manually, set SKIP_SSH_WAIT=true and run again"
          
          # Ask if the user wants to continue anyway
          read -p "Continue with deployment anyway? (y/n) " -n 1 -r
          echo
          if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Continuing with deployment..."
            break
          else
            echo "Aborting deployment. Try again later or troubleshoot SSH connection issues."
            AUTO_DEPLOY=false
            break
          fi
        fi
        
        # Wait before next attempt
        echo "Waiting 10 seconds before next attempt..."
        sleep 10
      fi
    done
  fi
  
  # Wait for user-data script to complete
  echo "Waiting for user-data script to complete..."
  for i in {1..30}; do
    if run_ssh_command "test -f /var/log/initial-setup.log && grep -q 'Initial EC2 setup completed successfully' /var/log/initial-setup.log" &>/dev/null; then
      echo "User-data script has completed successfully"
      break
    fi
    if [ $i -eq 30 ]; then
      echo "User-data script not completed after 30 attempts. Will continue but may fail."
    fi
    echo "Attempt $i/30 - waiting for user-data script to complete..."
    sleep 10
  done
  
  # Copy the update-postgres.sh script to the instance
  echo "Copying update-postgres.sh to the instance..."
  if copy_file_to_instance "$SCRIPT_DIR/update-postgres.sh" "/home/ec2-user/update-postgres.sh"; then
    echo "Successfully copied update-postgres.sh to the instance"
  else
    echo "Failed to copy update-postgres.sh to the instance"
    AUTO_DEPLOY=false
  fi
  
  # Make the script executable
  if [ "$AUTO_DEPLOY" = true ]; then
    echo "Making update-postgres.sh executable..."
    if run_ssh_command "chmod +x /home/ec2-user/update-postgres.sh"; then
      echo "Successfully made update-postgres.sh executable"
    else
      echo "Failed to make update-postgres.sh executable"
      AUTO_DEPLOY=false
    fi
  fi
  
  # Run the update-postgres.sh script
  if [ "$AUTO_DEPLOY" = true ]; then
    echo "Running update-postgres.sh script to set up PostgreSQL..."
    if run_ssh_command "db_username=\"$DB_USER\" db_password=\"$DB_PASSWORD\" db_name=\"$DB_NAME\" postgres_port=\"$DB_PORT\" /home/ec2-user/update-postgres.sh start"; then
      echo "Successfully ran update-postgres.sh"
      
      # Wait a moment for logs to be written
      sleep 5
      
      # Display the logs
      echo "Displaying update-postgres.sh logs:"
      run_ssh_command "cat /var/log/postgres-update-${DB_NAME}.log" || echo "Could not retrieve logs"
      
      echo ""
      echo "PostgreSQL has been set up successfully!"
      echo "You can now connect to the database using:"
      echo "psql -h $CONNECT_IP -U $DB_USER -d $DB_NAME -p $DB_PORT"
    else
      echo "Failed to run update-postgres.sh"
      echo "Please run the commands manually as shown above"
    fi
  fi
fi

# Turn off debugging
set +x

# Clean up temporary key file if it was created
if [ -n "$KEY_CONTENT" ] && [ -f "$KEY_FILE" ]; then
  rm -f "$KEY_FILE"
  echo "Removed temporary key file"
fi