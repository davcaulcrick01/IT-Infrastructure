#!/bin/bash
set -e

# Create a log file for the update script
LOGFILE="/var/log/postgres/postgres-update-${db_name:-default}.log"
exec > >(tee $LOGFILE) 2>&1

# Global variables - map directly to Terraform variables
POSTGRES_USER="${db_username:-}"
POSTGRES_PASSWORD="${db_password}"  # Password will be passed via environment variable
POSTGRES_DB="${db_name:-}"
POSTGRES_VERSION="${POSTGRES_VERSION:-15}"
POSTGRES_PORT="${postgres_port:-}"
BACKUP_BUCKET="${bucket_name:-}"
RETENTION_WEEKS="${backup_retention_weeks:-}"
INSTANCE_ID="$(curl -s http://169.254.169.254/latest/meta-data/instance-id)"
CONTAINER_NAME="postgres-${POSTGRES_DB}"
BACKUP_DIR="/data/backups/${POSTGRES_DB}"
NETWORK_NAME="${NETWORK_NAME:-${POSTGRES_DB}-network}"

# Command options
COMMAND="${1:-start}"

# Function to log messages with timestamps
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to handle errors
handle_error() {
  log "ERROR: $1"
  exit 1
}

# Validate required variables
validate_variables() {
  if [ -z "$POSTGRES_USER" ]; then
    handle_error "Database username not provided. Set db_username environment variable."
  fi
  
  if [ -z "$POSTGRES_DB" ]; then
    handle_error "Database name not provided. Set db_name environment variable."
  fi
  
  if [ -z "$POSTGRES_PORT" ]; then
    handle_error "Database port not provided. Set postgres_port environment variable."
  fi
  
  if [ -z "$POSTGRES_PASSWORD" ] && [ "$COMMAND" != "stop" ] && [ "$COMMAND" != "status" ] && [ "$COMMAND" != "list" ]; then
    handle_error "Database password not provided. Set db_password environment variable."
  fi
}

# Call validation for all commands except list and status
if [ "$COMMAND" != "list" ]; then
  validate_variables
fi

# Function to setup PostgreSQL in Docker
setup_postgres_docker() {
  log "Setting up PostgreSQL in Docker for database: ${POSTGRES_DB}..."
  
  # Check if PostgreSQL container is already running
  if docker ps | grep -q "${CONTAINER_NAME}"; then
    log "PostgreSQL container is already running, stopping it..."
    docker stop "${CONTAINER_NAME}" || log "Warning: Failed to stop existing PostgreSQL container"
    docker rm "${CONTAINER_NAME}" || log "Warning: Failed to remove existing PostgreSQL container"
  fi
  
  # Create Docker Compose file
  log "Creating Docker Compose file..."
  COMPOSE_FILE="/data/docker/docker-compose-${POSTGRES_DB}.yml"
  DATA_DIR="/data/docker/postgres-${POSTGRES_DB}"
  
  # Create data directory if it doesn't exist
  mkdir -p "${DATA_DIR}" || handle_error "Failed to create data directory"
  
  cat > "${COMPOSE_FILE}" << EOFDC || handle_error "Failed to create Docker Compose file"
version: '3.8'

services:
  ${CONTAINER_NAME}:
    container_name: ${CONTAINER_NAME}
    image: postgres:${POSTGRES_VERSION}
    restart: always
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
      PGDATA: /var/lib/postgresql/data/pgdata
    volumes:
      - ${DATA_DIR}:/var/lib/postgresql/data
    ports:
      - "${POSTGRES_PORT}:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER}"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - ${NETWORK_NAME}

networks:
  ${NETWORK_NAME}:
    driver: bridge
EOFDC
  
  # Start PostgreSQL container
  log "Starting PostgreSQL container..."
  cd /data/docker || handle_error "Failed to change to Docker directory"
  docker-compose -f "docker-compose-${POSTGRES_DB}.yml" up -d || handle_error "Failed to start PostgreSQL container"
  
  # Wait for PostgreSQL to be ready
  log "Waiting for PostgreSQL to be ready..."
  for i in {1..30}; do
    if docker exec "${CONTAINER_NAME}" pg_isready -U "${POSTGRES_USER}" > /dev/null 2>&1; then
      log "PostgreSQL is ready"
      break
    fi
    if [ $i -eq 30 ]; then
      handle_error "PostgreSQL failed to start within the expected time"
    fi
    log "Waiting for PostgreSQL to be ready... ($i/30)"
    sleep 2
  done
  
  log "PostgreSQL setup in Docker completed successfully"
}

# Function to stop PostgreSQL container
stop_postgres_docker() {
  log "Stopping PostgreSQL container for database: ${POSTGRES_DB}..."
  
  # Check if container exists
  if docker ps -a | grep -q "${CONTAINER_NAME}"; then
    docker stop "${CONTAINER_NAME}" || log "Warning: Failed to stop PostgreSQL container"
    log "PostgreSQL container stopped"
  else
    log "PostgreSQL container not found"
  fi
}

# Function to show PostgreSQL container status
show_status() {
  log "Checking status of PostgreSQL container for database: ${POSTGRES_DB}..."
  
  # Check if container exists
  if docker ps | grep -q "${CONTAINER_NAME}"; then
    log "PostgreSQL container is running"
    docker ps --filter "name=${CONTAINER_NAME}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    # Get container details
    log "Connection details:"
    echo "Database: ${POSTGRES_DB}"
    echo "User: ${POSTGRES_USER}"
    echo "Port: ${POSTGRES_PORT}"
    echo "Connection string: postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@localhost:${POSTGRES_PORT}/${POSTGRES_DB}"
  elif docker ps -a | grep -q "${CONTAINER_NAME}"; then
    log "PostgreSQL container exists but is not running"
    docker ps -a --filter "name=${CONTAINER_NAME}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
  else
    log "PostgreSQL container does not exist"
  fi
}

# Function to setup backup scripts
setup_backups() {
  log "Setting up backup scripts for database: ${POSTGRES_DB}..."
  
  # Create backup directory if it doesn't exist
  mkdir -p "${BACKUP_DIR}" || handle_error "Failed to create backup directory"
  
  # Create daily backup script
  DAILY_BACKUP_SCRIPT="/data/scripts/postgres-${POSTGRES_DB}-backup-daily.sh"
  
  cat > "${DAILY_BACKUP_SCRIPT}" << EOFB || handle_error "Failed to create daily backup script"
#!/bin/bash
# Daily backup script for PostgreSQL in Docker
BACKUP_DIR="${BACKUP_DIR}"
TIMESTAMP=\$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="\${BACKUP_DIR}/postgres_${POSTGRES_DB}_backup_\${TIMESTAMP}.sql.gz"

# Create backup directory if it doesn't exist
mkdir -p \${BACKUP_DIR}

# Create the backup
echo "Creating PostgreSQL backup for ${POSTGRES_DB}..."
docker exec ${CONTAINER_NAME} pg_dumpall -U ${POSTGRES_USER} | gzip > \${BACKUP_FILE}

# Keep only the last 7 daily backups
find \${BACKUP_DIR} -name "postgres_${POSTGRES_DB}_backup_*.sql.gz" -type f -mtime +7 -delete

echo "Daily backup completed at \$(date)"
EOFB
  chmod +x "${DAILY_BACKUP_SCRIPT}" || handle_error "Failed to make daily backup script executable"
  
  # Create weekly S3 backup script
  S3_BACKUP_SCRIPT="/data/scripts/postgres-${POSTGRES_DB}-backup-s3.sh"
  
  cat > "${S3_BACKUP_SCRIPT}" << EOFS || handle_error "Failed to create S3 backup script"
#!/bin/bash
# Weekly S3 backup script for PostgreSQL in Docker
BACKUP_DIR="${BACKUP_DIR}"
S3_BUCKET="${BACKUP_BUCKET}"
TIMESTAMP=\$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="\${BACKUP_DIR}/postgres_${POSTGRES_DB}_s3_backup_\${TIMESTAMP}.sql.gz"
INSTANCE_ID="${INSTANCE_ID}"
S3_PATH="weekly/\${INSTANCE_ID}/${POSTGRES_DB}/postgres_backup_\${TIMESTAMP}.sql.gz"

# Create the backup
echo "Creating PostgreSQL backup for S3..."
docker exec ${CONTAINER_NAME} pg_dumpall -U ${POSTGRES_USER} | gzip > \${BACKUP_FILE}

# Upload to S3
echo "Uploading backup to S3..."
aws s3 cp \${BACKUP_FILE} s3://\${S3_BUCKET}/\${S3_PATH}

# Delete old backups from S3 (keep last ${RETENTION_WEEKS} weeks)
echo "Cleaning up old S3 backups..."
WEEKS_TO_KEEP=${RETENTION_WEEKS}
aws s3 ls s3://\${S3_BUCKET}/weekly/\${INSTANCE_ID}/${POSTGRES_DB}/ | sort | head -n -\${WEEKS_TO_KEEP} | awk '{print \$4}' | xargs -I {} aws s3 rm s3://\${S3_BUCKET}/weekly/\${INSTANCE_ID}/${POSTGRES_DB}/{}

# Delete the local backup file
rm -f \${BACKUP_FILE}

echo "S3 backup completed at \$(date)"
EOFS
  chmod +x "${S3_BACKUP_SCRIPT}" || handle_error "Failed to make S3 backup script executable"
  
  # Setup cron jobs using systemd timers if crontab is not available
  log "Setting up scheduled jobs for backups..."
  
  # Check if crontab is available
  if ! command -v crontab &> /dev/null; then
    log "crontab not found, installing cronie..."
    
    # Try to install crontab package
    if grep -q "Amazon Linux 2023" /etc/os-release; then
      sudo dnf install -y cronie || log "Warning: Failed to install cronie, will use systemd timers instead"
      sudo systemctl enable crond && sudo systemctl start crond || log "Warning: Failed to start crond service"
    else
      sudo yum install -y cronie || log "Warning: Failed to install cronie, will use systemd timers instead"
      sudo systemctl enable crond && sudo systemctl start crond || log "Warning: Failed to start crond service"
    fi
  fi
  
  # Try using crontab again after installation
  if command -v crontab &> /dev/null; then
    log "Setting up cron jobs..."
    # Add daily backup job
    (crontab -l 2>/dev/null || echo "") | grep -v "postgres-${POSTGRES_DB}-backup-daily.sh" | { cat; echo "0 2 * * * ${DAILY_BACKUP_SCRIPT} >> /var/log/postgres/${POSTGRES_DB}-backup-daily.log 2>&1"; } | crontab -
    
    # Add weekly backup job
    (crontab -l 2>/dev/null || echo "") | grep -v "postgres-${POSTGRES_DB}-backup-s3.sh" | { cat; echo "0 3 * * 0 ${S3_BACKUP_SCRIPT} >> /var/log/postgres/${POSTGRES_DB}-backup-s3.log 2>&1"; } | crontab -
    
    log "Cron jobs configured successfully"
  else
    # Use systemd timers as a fallback
    log "Using systemd timers instead of cron jobs..."
    
    # Create systemd timer for daily backup
    sudo tee /etc/systemd/system/postgres-${POSTGRES_DB}-backup-daily.service << EOF > /dev/null
[Unit]
Description=Daily PostgreSQL Backup for ${POSTGRES_DB}
After=docker.service

[Service]
Type=oneshot
ExecStart=${DAILY_BACKUP_SCRIPT}
User=ec2-user

[Install]
WantedBy=multi-user.target
EOF

    sudo tee /etc/systemd/system/postgres-${POSTGRES_DB}-backup-daily.timer << EOF > /dev/null
[Unit]
Description=Run PostgreSQL ${POSTGRES_DB} backup daily at 2 AM

[Timer]
OnCalendar=*-*-* 02:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

    # Create systemd timer for weekly S3 backup
    sudo tee /etc/systemd/system/postgres-${POSTGRES_DB}-backup-s3.service << EOF > /dev/null
[Unit]
Description=Weekly PostgreSQL S3 Backup for ${POSTGRES_DB}
After=docker.service

[Service]
Type=oneshot
ExecStart=${S3_BACKUP_SCRIPT}
User=ec2-user

[Install]
WantedBy=multi-user.target
EOF

    sudo tee /etc/systemd/system/postgres-${POSTGRES_DB}-backup-s3.timer << EOF > /dev/null
[Unit]
Description=Run PostgreSQL ${POSTGRES_DB} S3 backup weekly on Sunday at 3 AM

[Timer]
OnCalendar=Sun *-*-* 03:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

    # Enable and start the timers
    sudo systemctl daemon-reload
    sudo systemctl enable postgres-${POSTGRES_DB}-backup-daily.timer
    sudo systemctl start postgres-${POSTGRES_DB}-backup-daily.timer
    sudo systemctl enable postgres-${POSTGRES_DB}-backup-s3.timer
    sudo systemctl start postgres-${POSTGRES_DB}-backup-s3.timer
    
    log "Systemd timers configured successfully"
  fi
  
  log "Backup scripts setup completed"
}

# Function to run a test backup
test_backup() {
  log "Creating initial test backup..."
  "${DAILY_BACKUP_SCRIPT}" || log "Warning: Initial backup test failed, but continuing setup"
}

# Function to list all PostgreSQL containers
list_containers() {
  log "Listing all PostgreSQL containers..."
  
  echo "RUNNING CONTAINERS:"
  docker ps --filter "name=postgres-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
  
  echo -e "\nALL CONTAINERS (including stopped):"
  docker ps -a --filter "name=postgres-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
  
  echo -e "\nCOMPOSE FILES:"
  ls -la /data/docker/docker-compose-*.yml 2>/dev/null || echo "No compose files found"
}

# Main function to run all steps sequentially
main() {
  case "$COMMAND" in
    start)
      log "Starting PostgreSQL setup for database: ${POSTGRES_DB}"
      setup_postgres_docker
      setup_backups
      test_backup
      log "PostgreSQL setup completed successfully"
      ;;
    stop)
      stop_postgres_docker
      ;;
    status)
      show_status
      ;;
    list)
      list_containers
      ;;
    restart)
      log "Restarting PostgreSQL for database: ${POSTGRES_DB}"
      stop_postgres_docker
      setup_postgres_docker
      log "PostgreSQL restart completed successfully"
      ;;
    *)
      log "Unknown command: $COMMAND"
      echo "Usage: DB_NAME=name DB_USER=user DB_PASSWORD=password ./update-postgres.sh [start|stop|status|list|restart]"
      exit 1
      ;;
  esac
}

# Run the main function
main 