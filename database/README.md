# PostgreSQL Database Management on AWS Infrastructure

This documentation explains how to use the infrastructure scripts to deploy and manage PostgreSQL databases in Docker containers on AWS EC2 instances.

## Table of Contents

1. [Overview](#overview)
2. [File Structure](#file-structure)
3. [Scripts](#scripts)
   - [userdata.sh](#userdatash)
   - [update-postgres.sh](#update-postgressh)
   - [deploy-database.sh](#deploy-databasesh)
   - [manage-databases.sh](#manage-databasessh)
4. [Common Workflows](#common-workflows)
5. [Troubleshooting](#troubleshooting)

## Overview

This infrastructure setup allows you to:

1. Deploy EC2 instances with Docker and necessary tools preinstalled
2. Create and manage multiple PostgreSQL database containers on these instances
3. Configure automated backups to S3
4. Separate core infrastructure from database deployment
5. Support different database configurations based on Terraform variables

## File Structure

```
Infrastructure/IT-Infrastructure/database/
├── car_rental_terraform.tfvars            # Configuration for car rental database
├── caulcrick_properties.tfvars            # Configuration for Caulcrick properties database
├── caulcrick_homes_terraform.tfvars       # Configuration for Caulcrick homes database
├── main.tf                                # Main Terraform configuration
├── variables.tf                           # Terraform variable definitions
├── outputs.tf                             # Terraform outputs
├── scripts/
│   ├── deploy-database.sh                 # Script to deploy infrastructure via Terraform
│   ├── manage-databases.sh                # Script to manage database containers
│   ├── userdata.sh                        # EC2 initialization script
│   └── update-postgres.sh                 # PostgreSQL container management script
└── README.md                              # Documentation
```

## Scripts

### userdata.sh

This script runs automatically when an EC2 instance is launched. It sets up the core infrastructure:

- Updates the system
- Installs Docker and Docker Compose
- Installs AWS SSM Agent
- Installs AWS CLI
- Sets up CloudWatch monitoring
- Creates data directories

**Note**: This script doesn't set up PostgreSQL - that's handled separately.

### update-postgres.sh

This script manages PostgreSQL containers. It supports multiple commands:

```bash
# Basic usage
DB_USER="[db_username]" DB_PASSWORD="[db_password]" DB_NAME="[db_name]" POSTGRES_PORT="[postgres_port]" ./update-postgres.sh [command]
```

Available commands:

- `start`: Create and start a PostgreSQL container (default)
- `stop`: Stop a PostgreSQL container
- `status`: Show status of a PostgreSQL container
- `restart`: Restart a PostgreSQL container
- `list`: List all PostgreSQL containers

Environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| DB_USER | Database username (from db_username) | dbadmin |
| DB_PASSWORD | Database password (from db_password) | (Required) |
| DB_NAME | Database name (from db_name) | greyzone_intelligence |
| POSTGRES_VERSION | PostgreSQL version | 15 |
| POSTGRES_PORT | PostgreSQL port (from postgres_port) | 5432 |
| BACKUP_BUCKET | S3 bucket for backups (from bucket_name) | database-bucket |
| RETENTION_WEEKS | Weeks to keep backups (from backup_retention_weeks) | 4 |

### deploy-database.sh

This script deploys the infrastructure using Terraform:

```bash
./deploy-database.sh <environment>
```

For example:
```bash
./deploy-database.sh caulcrick_properties
```

This will:
1. Find `caulcrick_properties.tfvars`
2. Apply the Terraform configuration
3. Output instructions for connecting to the EC2 instance
4. Show how to run the update-postgres.sh script with the correct parameters

### manage-databases.sh

This script combines features of both deploy-database.sh and update-postgres.sh:

```bash
./manage-databases.sh [options] COMMAND
```

Available commands:

- `deploy ENVIRONMENT`: Deploy infrastructure using Terraform
- `create NAME`: Create a new database container
- `start NAME`: Start an existing database container
- `stop NAME`: Stop a database container
- `restart NAME`: Restart a database container
- `status NAME`: Show status of a database container
- `list`: List all database containers

Options:

| Option | Description |
|--------|-------------|
| -u, --user USER | Database username (maps to db_username) |
| -p, --password PASS | Database password (maps to db_password) |
| -P, --port PORT | Database port (maps to postgres_port) |
| -v, --version VER | PostgreSQL version |
| -b, --bucket BUCKET | S3 backup bucket name (maps to bucket_name) |
| -r, --retention WEEKS | Backup retention in weeks (maps to backup_retention_weeks) |
| -h, --help | Show help message |

## Common Workflows

### Deploying a New Database Environment

1. Create a new Terraform variables file (e.g., `new_project.tfvars`) with your specific variables:
   ```
   # Database Configuration
   db_username      = "..."
   db_password      = "..." 
   db_name          = "..."
   postgres_port    = "..."
   
   # Additional required configuration
   ami_id           = "..."
   instance_type    = "..."
   # ... other variables
   ```

2. Deploy the infrastructure:
   ```bash
   ./scripts/deploy-database.sh new_project
   ```

3. SSH into the EC2 instance
4. Create the database container:
   ```bash
   cd /data/scripts
   DB_USER="[db_username]" DB_PASSWORD="[db_password]" DB_NAME="[db_name]" POSTGRES_PORT="[postgres_port]" ./update-postgres.sh start
   ```

### Adding Another Database to an Existing Instance

1. SSH into the EC2 instance
2. Run the update-postgres.sh script with different parameters:
   ```bash
   cd /data/scripts
   DB_USER="[db_username]" DB_PASSWORD="[db_password]" DB_NAME="[db_name]" POSTGRES_PORT="[postgres_port]" ./update-postgres.sh start
   ```

### Managing Databases

```bash
# Check status of all databases
./update-postgres.sh list

# Check status of a specific database
DB_NAME="[db_name]" ./update-postgres.sh status

# Stop a database
DB_NAME="[db_name]" ./update-postgres.sh stop

# Start a database
DB_USER="[db_username]" DB_PASSWORD="[db_password]" DB_NAME="[db_name]" POSTGRES_PORT="[postgres_port]" ./update-postgres.sh start

# Restart a database
DB_USER="[db_username]" DB_PASSWORD="[db_password]" DB_NAME="[db_name]" POSTGRES_PORT="[postgres_port]" ./update-postgres.sh restart
```

## Troubleshooting

### Common Issues

1. **Container won't start**:
   - Check Docker logs: `docker logs postgres-[db_name]`
   - Verify port availability: `netstat -tuln | grep [postgres_port]`
   - Check disk space: `df -h`

2. **Can't connect to database**:
   - Verify container is running: `docker ps | grep postgres-[db_name]`
   - Check security group settings in AWS console
   - Test connection locally: `docker exec -it postgres-[db_name] psql -U [db_username] -d [db_name]`

3. **Backup failures**:
   - Check S3 bucket permissions for [bucket_name]
   - Verify IAM role permissions for the EC2 instance
   - Check backup logs: `/var/log/postgres-[db_name]-backup-daily.log`

### Log Files

- EC2 setup: `/var/log/initial-setup.log`
- PostgreSQL container setup: `/var/log/postgres-update-[db_name].log`
- Daily backups: `/var/log/postgres-[db_name]-backup-daily.log`
- Weekly S3 backups: `/var/log/postgres-[db_name]-backup-s3.log`

### Commands to Check Container Status

```bash
# Check if container is running
docker ps | grep postgres-[db_name]

# Check container logs
docker logs postgres-[db_name]

# Check container resource usage
docker stats postgres-[db_name]

# Connect to PostgreSQL
docker exec -it postgres-[db_name] psql -U [db_username] -d [db_name]
```

---

For additional support or to customize the setup further, refer to the script source code and Terraform configuration files. 