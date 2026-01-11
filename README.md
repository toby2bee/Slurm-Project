# Deployment Guide with Docker Secrets

> **⚠️ DISCLAIMER: FOR LEARNING AND TESTING PURPOSES ONLY**
>
> This project is designed for educational and practice purposes to learn SLURM cluster management, Docker orchestration, and job scheduling concepts. It is **NOT intended for production use** and should **NOT be used in production environments** without significant modifications for security, scalability, and reliability.
>
> For production deployments, consult official SLURM documentation and follow enterprise-grade best practices.

This guide explains how to set up and deploy the Slurm project using Docker secrets for secure password management.

## Quick Start

### Windows (PowerShell)
```powershell
# Run the setup script
.\setup-secrets.ps1

# Deploy the stack
docker-compose up -d         #goto RUNJOB.md
```

### Linux/macOS (Bash)
```bash
# Make script executable
chmod +x setup-secrets.sh

# Run the setup script
./setup-secrets.sh

# Deploy the stack
docker-compose up -d         #goto RUNJOB.md
```

### Manual Setup (All Platforms)
```bash
# Create secrets directory
mkdir -p secrets

# Create secret files (replace with your passwords)
echo -n "your_password" > secrets/mysql_root_password.txt
echo -n "your_password" > secrets/mysql_password.txt
echo -n "your_password" > secrets/root_password.txt
echo -n "your_password" > secrets/wunmi_password.txt

# Set permissions (Linux/macOS)
chmod 600 secrets/*.txt

# Deploy
docker-compose up -d           #goto RUNJOB.md
```

## Prerequisites

- Docker and Docker Compose installed
- Access to create files and directories in the project

## Step 1: Create the Secrets Directory

Create a directory to store secret files (this directory is already in `.gitignore`):

```bash
mkdir -p secrets
```

## Step 2: Create Secret Files

Create individual secret files for each password. **Use strong, unique passwords for production!**

### Option A: Using echo (Simple, but passwords visible in shell history)

```bash
# MySQL root password
echo -n "your_secure_mysql_root_password" > secrets/mysql_root_password.txt

# MySQL slurm user password
echo -n "your_secure_mysql_slurm_password" > secrets/mysql_password.txt

# Root user password for SSH access
echo -n "your_secure_root_password" > secrets/root_password.txt

# Wunmi user password for SSH access
echo -n "your_secure_wunmi_password" > secrets/wunmi_password.txt
```

### Option B: Using openssl (More secure, generates random passwords)

```bash
# Generate random passwords
openssl rand -base64 32 > secrets/mysql_root_password.txt
openssl rand -base64 32 > secrets/mysql_password.txt
openssl rand -base64 32 > secrets/root_password.txt
openssl rand -base64 32 > secrets/wunmi_password.txt
```

## Step 3: Set Proper Permissions

Ensure secret files have restrictive permissions:

```bash
chmod 600 secrets/*.txt
```

## Step 4: Create .env File (Optional - for environment variables)

Create a `.env` file in the project root for non-secret environment variables:

```bash
cat > .env << EOF
# MySQL Database Configuration
MYSQL_DATABASE=slurm_acct_db
MYSQL_USER=slurm

# Note: Passwords are managed via Docker secrets, not environment variables
# See secrets/ directory for password files
EOF
```

**Important:** The `.env` file should NOT contain passwords. Passwords are managed through Docker secrets files.

## Step 5: Deploy the Stack

### Using Docker Compose (Recommended for development)

```bash
# Build and start all services
docker-compose build
docker-compose up -d    #goto RUNJOB.md

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

### Using Docker Swarm (Recommended for production)

If you want to use Docker Swarm mode with native secrets:

```bash
# Initialize swarm (if not already initialized)
docker swarm init

# Create Docker Swarm secrets
echo -n "your_secure_mysql_root_password" | docker secret create mysql_root_password -
echo -n "your_secure_mysql_slurm_password" | docker secret create mysql_password -
echo -n "your_secure_root_password" | docker secret create root_password -
echo -n "your_secure_wunmi_password" | docker secret create wunmi_password -

# Deploy the stack (requires docker-compose.yml to be updated for swarm mode)
docker stack deploy -c docker-compose.yml slurm-stack
```

## Step 6: Verify Deployment

```bash
# Check running containers
docker-compose ps

# Check MySQL connection
docker-compose exec mysql mysql -u root -p$(cat secrets/mysql_root_password.txt) -e "SHOW DATABASES;"

# Check Slurm services
docker-compose exec controller sinfo
docker-compose exec controller scontrol show nodes
```

## Security Best Practices

1. **Never commit secrets to Git**: The `.gitignore` file excludes:
   - `.env` files
   - `secrets/` directory
   - All `*.secret` and `*.key` files

2. **Use strong passwords**: Generate random passwords using `openssl rand -base64 32`

3. **Restrict file permissions**: Always use `chmod 600` for secret files

4. **Rotate passwords regularly**: Update secret files and restart containers

5. **Use Docker Swarm secrets in production**: For production deployments, use Docker Swarm mode with native secrets management

## Troubleshooting

### Secret files not found

If you see errors about missing secret files:
- Ensure `secrets/` directory exists
- Verify all four secret files are present
- Check file permissions (`chmod 600 secrets/*.txt`)

### MySQL connection issues

- Verify MySQL secrets are correct
- Check MySQL container logs: `docker-compose logs mysql`
- Ensure MySQL container is healthy: `docker-compose ps mysql`

### Password not working

- Verify the secret file contains the correct password (no newlines)
- Check that `entrypoint.sh` is reading from `/run/secrets/`
- Restart the affected container: `docker-compose restart <service-name>`

## Updating Passwords

To update a password:

1. Update the secret file:
   ```bash
   echo -n "new_password" > secrets/mysql_password.txt
   chmod 600 secrets/mysql_password.txt
   ```

2. Restart the affected service:
   ```bash
   docker-compose restart mysql slurmdbd
   ```

## File Structure

```
slurm-project/
├── .env                    # Environment variables (non-sensitive)
├── .gitignore             # Git ignore rules
├── .dockerignore          # Docker build ignore rules
├── docker-compose.yml     # Docker Compose configuration
├── .secrets/               # Secret files (NOT in git)
│   ├── mysql_root_password.txt
│   ├── mysql_password.txt
│   ├── root_password.txt
│   └── wunmi_password.txt
└── ...
```

