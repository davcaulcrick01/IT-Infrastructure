#!/bin/bash

# This script helps manage multiple PostgreSQL databases on an EC2 instance
# It uses the update-postgres.sh script to create/manage containers

# Function to display usage information
usage() {
  echo "Usage: $0 [options] COMMAND"
  echo ""
  echo "Commands:"
  echo "  deploy APP_NAME      - Deploy infrastructure using Terraform"
  echo "  create NAME          - Create a new database container"
  echo "  start NAME           - Start an existing database container"
  echo "  stop NAME            - Stop a database container"
  echo "  restart NAME         - Restart a database container"
  echo "  status NAME          - Show status of a database container"
  echo "  list                 - List all database containers"
  echo "  logs NAME            - View logs for a database container"
  echo ""
  echo "Options:"
  echo "  -u, --user USER      - Database username (db_username)"
  echo "  -p, --password PASS  - Database password (db_password)"
  echo "  -P, --port PORT      - Database port (postgres_port)"
  echo "  -v, --version VER    - PostgreSQL version"
  echo "  -b, --bucket BUCKET  - S3 backup bucket name (bucket_name)"
  echo "  -r, --retention WEEKS- Backup retention in weeks (backup_retention_weeks)"
  echo "  -m, --manual         - Manual mode (don't auto-execute commands)"
  echo "  -h, --help           - Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0 deploy APP_NAME                - Deploy using APP_NAME.tfvars"
  echo "  $0 -p PASSWORD create DB_NAME     - Create DB_NAME database container"
  echo "  $0 list                           - List all database containers"
  echo "  $0 status DB_NAME                 - Show status of DB_NAME database"
  echo "  $0 logs DB_NAME                   - View logs for DB_NAME"
}

# Add new logs command to see logs in real-time
logs_command() {
  local db_name="$1"
  if [ -z "$db_name" ]; then
    echo "Error: Database name is required for logs command"
    exit 1
  fi
  
  echo "Viewing logs for database $db_name..."
  if [ -f "/var/log/postgres-update-${db_name}.log" ]; then
    tail -f "/var/log/postgres-update-${db_name}.log"
  else
    echo "Log file not found. Has the database been set up?"
    exit 1
  fi
}

# Parse command-line arguments
POSITIONAL=()
MANUAL_MODE=false

while [[ $# -gt 0 ]]; do
  key="$1"

  case $key in
    -u|--user)
      db_username="$2"
      shift
      shift
      ;;
    -p|--password)
      db_password="$2"
      shift
      shift
      ;;
    -P|--port)
      postgres_port="$2"
      shift
      shift
      ;;
    -v|--version)
      POSTGRES_VERSION="$2"
      shift
      shift
      ;;
    -b|--bucket)
      bucket_name="$2"
      shift
      shift
      ;;
    -r|--retention)
      backup_retention_weeks="$2"
      shift
      shift
      ;;
    -m|--manual)
      MANUAL_MODE=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done
set -- "${POSITIONAL[@]}"

# Check if command is provided
if [ -z "$1" ]; then
  usage
  exit 1
fi

COMMAND="$1"
ARGUMENT="$2"

case "$COMMAND" in
  deploy)
    # Check if environment argument is provided
    if [ -z "$ARGUMENT" ]; then
      echo "Error: Application name is required for deploy command"
      echo "Usage: $0 deploy APP_NAME"
      exit 1
    fi

    DEPLOY_CMD="./deploy-database.sh $ARGUMENT"
    if [ "$MANUAL_MODE" = true ]; then
      DEPLOY_CMD="$DEPLOY_CMD --manual"
    fi
    
    echo "Executing: $DEPLOY_CMD"
    $DEPLOY_CMD
    ;;
    
  logs)
    logs_command "$ARGUMENT"
    ;;

  create|start|stop|restart|status)
    # Check if database name argument is provided
    if [ -z "$ARGUMENT" ]; then
      echo "Error: Database name is required for $COMMAND command"
      echo "Usage: $0 $COMMAND DATABASE_NAME"
      exit 1
    fi

    db_name="$ARGUMENT"
    
    # Check if we need to extract values from tfvars
    if [ -f "${db_name}.tfvars" ]; then
      TFVARS_FILE="${db_name}.tfvars"
      echo "Found matching tfvars file: $TFVARS_FILE"
    elif [ -f "${db_name}_terraform.tfvars" ]; then
      TFVARS_FILE="${db_name}_terraform.tfvars"
      echo "Found matching tfvars file: $TFVARS_FILE"
    fi
      
    if [ -n "$TFVARS_FILE" ]; then
      # Extract database variables from tfvars file if not provided
      if [ -z "$db_username" ]; then
        db_username=$(grep 'db_username' "$TFVARS_FILE" | cut -d '=' -f2 | tr -d ' "')
      fi
      
      if [ -z "$postgres_port" ]; then
        postgres_port=$(grep 'postgres_port' "$TFVARS_FILE" | cut -d '=' -f2 | tr -d ' "')
      fi
      
      if [ -z "$bucket_name" ]; then
        bucket_name=$(grep 'bucket_name' "$TFVARS_FILE" | cut -d '=' -f2 | tr -d ' "')
      fi
      
      if [ -z "$backup_retention_weeks" ]; then
        backup_retention_weeks=$(grep 'backup_retention_weeks' "$TFVARS_FILE" | cut -d '=' -f2 | tr -d ' "')
      fi
    fi
    
    # Set default values if not provided
    db_username="${db_username:-}"
    postgres_port="${postgres_port:-}"
    POSTGRES_VERSION="${POSTGRES_VERSION:-}"
    bucket_name="${bucket_name:-}"
    backup_retention_weeks="${backup_retention_weeks:-}"
    
    # Check for password if needed
    if [ "$COMMAND" = "create" ] || [ "$COMMAND" = "start" ] || [ "$COMMAND" = "restart" ]; then
      if [ -z "$db_password" ]; then
        read -s -p "Enter password for database $db_name: " db_password
        echo ""
        if [ -z "$db_password" ]; then
          echo "Error: Password is required"
          exit 1
        fi
      fi
    fi
    
    # Map our commands to update-postgres.sh commands
    POSTGRES_COMMAND="$COMMAND"
    if [ "$COMMAND" = "create" ]; then
      POSTGRES_COMMAND="start"
    fi
    
    # Run the update-postgres.sh script with the appropriate variables
    echo "Running: db_username=$db_username db_name=$db_name postgres_port=$postgres_port POSTGRES_VERSION=$POSTGRES_VERSION bucket_name=$bucket_name backup_retention_weeks=$backup_retention_weeks ./update-postgres.sh $POSTGRES_COMMAND"
    
    db_username="$db_username" \
    db_password="$db_password" \
    db_name="$db_name" \
    postgres_port="$postgres_port" \
    POSTGRES_VERSION="$POSTGRES_VERSION" \
    bucket_name="$bucket_name" \
    backup_retention_weeks="$backup_retention_weeks" \
    ./update-postgres.sh "$POSTGRES_COMMAND"
    ;;

  list)
    # List all PostgreSQL containers
    ./update-postgres.sh list
    ;;

  *)
    echo "Unknown command: $COMMAND"
    usage
    exit 1
    ;;
esac 