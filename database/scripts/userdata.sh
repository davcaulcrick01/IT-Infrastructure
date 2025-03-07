#!/bin/bash
set -e

# Create a log file for the user data script
# Use sudo to ensure we have permission to write to the log file
sudo mkdir -p /var/log
sudo touch /var/log/initial-setup.log
exec > >(sudo tee /var/log/initial-setup.log) 2>&1

# Global variables
REGION="$(curl -s http://169.254.169.254/latest/meta-data/placement/region)"
INSTANCE_ID="$(curl -s http://169.254.169.254/latest/meta-data/instance-id)"

# Function to log messages with timestamps
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to handle errors
handle_error() {
  log "ERROR: $1"
  # Don't exit with error code, just log the error and continue
  # This prevents instance termination
}

# Function to update the system
update_system() {
  log "Updating system packages..."
  if grep -q "Amazon Linux 2023" /etc/os-release; then
    # For Amazon Linux 2023
    sudo dnf update -y || handle_error "Failed to update system packages"
    sudo dnf install -y cronie || handle_error "Failed to install cronie"
    sudo systemctl enable crond || handle_error "Failed to enable crond service"
    sudo systemctl start crond || handle_error "Failed to start crond service"
  else
    # For Amazon Linux 2
    sudo yum update -y || handle_error "Failed to update system packages"
    sudo yum install -y cronie || handle_error "Failed to install cronie"
    sudo systemctl enable crond || handle_error "Failed to enable crond service"
    sudo systemctl start crond || handle_error "Failed to start crond service"
  fi
}

# Function to install Docker
install_docker() {
  log "Installing Docker..."
  
  # Check if Docker is already installed
  if command -v docker &> /dev/null; then
    log "Docker is already installed, updating..."
    if grep -q "Amazon Linux 2023" /etc/os-release; then
      sudo dnf update -y docker || handle_error "Failed to update Docker"
    else
      sudo yum update -y docker || handle_error "Failed to update Docker"
    fi
  else
    # Install Docker based on Amazon Linux version
    if grep -q "Amazon Linux 2" /etc/os-release; then
      # For Amazon Linux 2
      if command -v amazon-linux-extras &> /dev/null; then
        sudo amazon-linux-extras install -y docker || handle_error "Failed to install Docker on Amazon Linux 2"
      else
        log "amazon-linux-extras command not found, installing Docker using yum..."
        sudo yum install -y docker || handle_error "Failed to install Docker on Amazon Linux 2"
      fi
    else
      # For Amazon Linux 2023
      log "Detected Amazon Linux 2023, installing Docker..."
      sudo dnf install -y docker || handle_error "Failed to install Docker on Amazon Linux 2023"
    fi
  fi
  
  # Start and enable Docker service
  sudo systemctl enable docker || handle_error "Failed to enable Docker service"
  sudo systemctl start docker || handle_error "Failed to start Docker service"
  
  # Create docker group if it doesn't exist
  sudo groupadd -f docker || handle_error "Failed to create docker group"
  
  # Add ec2-user to docker group
  sudo usermod -a -G docker ec2-user || handle_error "Failed to add ec2-user to docker group"
  
  # Install Docker Compose
  log "Installing Docker Compose..."
  DOCKER_COMPOSE_VERSION="2.24.6"
  
  # Check architecture
  ARCH=$(uname -m)
  if [ "$ARCH" = "x86_64" ]; then
    COMPOSE_ARCH="x86_64"
  elif [ "$ARCH" = "aarch64" ]; then
    COMPOSE_ARCH="aarch64"
  else
    handle_error "Unsupported architecture: $ARCH"
  fi
  
  sudo curl -L "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-linux-${COMPOSE_ARCH}" -o /usr/local/bin/docker-compose || handle_error "Failed to download Docker Compose"
  sudo chmod +x /usr/local/bin/docker-compose || handle_error "Failed to make Docker Compose executable"
  
  # Verify Docker installation
  sudo docker --version || handle_error "Docker installation verification failed"
  sudo docker-compose --version || handle_error "Docker Compose installation verification failed"
  
  log "Docker installation completed successfully"
}

# Function to install and configure SSM Agent
install_ssm_agent() {
  log "Installing AWS Systems Manager (SSM) Agent..."
  
  # Check if SSM Agent is already installed
  if systemctl list-unit-files | grep -q amazon-ssm-agent; then
    log "SSM Agent is already installed, updating..."
    if grep -q "Amazon Linux 2023" /etc/os-release; then
      sudo dnf update -y amazon-ssm-agent || handle_error "Failed to update SSM Agent"
    else
      sudo yum update -y amazon-ssm-agent || handle_error "Failed to update SSM Agent"
    fi
  else
    # Install SSM Agent based on the region and architecture
    log "Installing SSM Agent..."
    
    # Determine system architecture
    ARCH=$(uname -m)
    if [ "$ARCH" = "x86_64" ]; then
      SSM_URL="https://s3.$REGION.amazonaws.com/amazon-ssm-$REGION/latest/linux_amd64/amazon-ssm-agent.rpm"
    elif [ "$ARCH" = "aarch64" ]; then
      SSM_URL="https://s3.$REGION.amazonaws.com/amazon-ssm-$REGION/latest/linux_arm64/amazon-ssm-agent.rpm"
    else
      handle_error "Unsupported architecture: $ARCH"
    fi
    
    # Download and install SSM Agent
    log "Downloading SSM Agent from $SSM_URL"
    curl -s "$SSM_URL" -o /tmp/amazon-ssm-agent.rpm || handle_error "Failed to download SSM Agent"
    if grep -q "Amazon Linux 2023" /etc/os-release; then
      sudo dnf install -y /tmp/amazon-ssm-agent.rpm || handle_error "Failed to install SSM Agent"
    else
      sudo yum install -y /tmp/amazon-ssm-agent.rpm || handle_error "Failed to install SSM Agent"
    fi
    rm -f /tmp/amazon-ssm-agent.rpm
  fi
  
  # Enable and start SSM Agent
  log "Enabling and starting SSM Agent..."
  sudo systemctl enable amazon-ssm-agent || handle_error "Failed to enable SSM Agent"
  sudo systemctl start amazon-ssm-agent || handle_error "Failed to start SSM Agent"
  
  # Verify SSM Agent is running
  if sudo systemctl is-active amazon-ssm-agent > /dev/null; then
    log "SSM Agent is running successfully"
  else
    handle_error "SSM Agent failed to start"
  fi
  
  # Create a cron job to check and restart SSM Agent if needed
  log "Setting up SSM Agent monitoring..."
  sudo tee /etc/cron.hourly/check-ssm-agent << EOF || handle_error "Failed to create SSM Agent monitoring script"
#!/bin/bash
# Check if SSM Agent is running and restart if needed
if ! systemctl is-active amazon-ssm-agent > /dev/null; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] SSM Agent is not running. Attempting to restart..."
  systemctl restart amazon-ssm-agent
fi
EOF
  sudo chmod +x /etc/cron.hourly/check-ssm-agent || handle_error "Failed to make SSM Agent monitoring script executable"
}

# Function to install AWS CLI
install_aws_cli() {
  log "Installing AWS CLI..."
  
  # Check if AWS CLI is already installed
  if command -v aws &> /dev/null; then
    log "AWS CLI is already installed, updating..."
    if grep -q "Amazon Linux 2023" /etc/os-release; then
      sudo dnf update -y awscli || handle_error "Failed to update AWS CLI"
    else
      sudo yum update -y awscli || handle_error "Failed to update AWS CLI"
    fi
  else
    if grep -q "Amazon Linux 2023" /etc/os-release; then
      sudo dnf install -y awscli || handle_error "Failed to install AWS CLI"
    else
      sudo yum install -y awscli || handle_error "Failed to install AWS CLI"
    fi
  fi
  
  # Verify AWS CLI installation
  aws --version || handle_error "AWS CLI installation verification failed"
  
  log "AWS CLI installation completed successfully"
}

# Function to setup CloudWatch agent
setup_cloudwatch() {
  log "Installing CloudWatch agent..."
  if grep -q "Amazon Linux 2023" /etc/os-release; then
    sudo dnf install -y amazon-cloudwatch-agent || handle_error "Failed to install CloudWatch agent"
  else
    sudo yum install -y amazon-cloudwatch-agent || handle_error "Failed to install CloudWatch agent"
  fi
  
  log "Configuring CloudWatch agent..."
  # Create CloudWatch agent configuration directory if it doesn't exist
  sudo mkdir -p /opt/aws/amazon-cloudwatch-agent/etc/
  
  # Create CloudWatch agent configuration
  sudo tee /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << EOF || handle_error "Failed to create CloudWatch agent configuration"
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "root"
  },
  "metrics": {
    "metrics_collected": {
      "disk": {
        "measurement": [
          "used_percent"
        ],
        "resources": [
          "/"
        ]
      },
      "mem": {
        "measurement": [
          "mem_used_percent"
        ]
      },
      "docker": {
        "measurement": [
          "container_cpu_usage_percent",
          "container_memory_usage_percent"
        ]
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/initial-setup.log",
            "log_group_name": "ec2-setup-logs",
            "log_stream_name": "${INSTANCE_ID}/initial-setup"
          },
          {
            "file_path": "/var/log/amazon/ssm/amazon-ssm-agent.log",
            "log_group_name": "ssm-agent-logs",
            "log_stream_name": "${INSTANCE_ID}"
          },
          {
            "file_path": "/var/log/docker.log",
            "log_group_name": "docker-logs",
            "log_stream_name": "${INSTANCE_ID}"
          }
        ]
      }
    }
  }
}
EOF
  
  log "Starting CloudWatch agent..."
  sudo systemctl enable amazon-cloudwatch-agent || handle_error "Failed to enable CloudWatch agent"
  sudo systemctl start amazon-cloudwatch-agent || handle_error "Failed to start CloudWatch agent"
}

# Function to create data directories
setup_data_directories() {
  log "Setting up data directories..."
  
  # Create directories for Docker volumes
  sudo mkdir -p /data/docker || handle_error "Failed to create Docker data directory"
  sudo mkdir -p /data/backups || handle_error "Failed to create backups directory"
  sudo mkdir -p /data/scripts || handle_error "Failed to create scripts directory"
  
  # Create log directory
  sudo mkdir -p /var/log/postgres || handle_error "Failed to create postgres log directory"
  
  # Set proper permissions
  sudo chmod -R 755 /data || handle_error "Failed to set permissions on data directory"
  
  # Make ec2-user the owner of these directories
  sudo chown -R ec2-user:ec2-user /data || handle_error "Failed to set ownership on data directory"
  sudo chown -R ec2-user:ec2-user /var/log/postgres || handle_error "Failed to set ownership on postgres log directory"
  
  # Allow writing to main log directory (for the update script)
  sudo chmod 777 /var/log || handle_error "Failed to set permissions on log directory"
  
  log "Data directories setup completed"
}

# Main function to run all steps sequentially
main() {
  log "Starting initial EC2 setup"
  update_system
  install_docker
  install_ssm_agent
  install_aws_cli
  setup_cloudwatch
  setup_data_directories
  
  log "Initial EC2 setup completed successfully"
  log "The system is now ready for application deployment"
}

# Run the main function
main 