#!/bin/bash
# Script to set up Docker secrets for the Slurm project
# This script helps create secret files securely

set -e

SECRETS_DIR="./secrets"

# Create secrets directory if it doesn't exist
mkdir -p "$SECRETS_DIR"

echo "Setting up Docker secrets for Slurm project..."
echo "=============================================="
echo ""

# Function to create a secret file
create_secret() {
    local secret_name=$1
    local prompt=$2
    local file_path="$SECRETS_DIR/${secret_name}.txt"
    
    if [ -f "$file_path" ]; then
        read -p "$prompt file already exists. Overwrite? (y/N): " overwrite
        if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
            echo "Skipping $secret_name..."
            return
        fi
    fi
    
    read -s -p "$prompt: " password
    echo
    echo -n "$password" > "$file_path"
    chmod 600 "$file_path"
    echo "✓ Created $file_path"
}

# Function to generate random password
generate_random_secret() {
    local secret_name=$1
    local file_path="$SECRETS_DIR/${secret_name}.txt"
    
    if [ -f "$file_path" ]; then
        read -p "$secret_name file already exists. Overwrite? (y/N): " overwrite
        if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
            echo "Skipping $secret_name..."
            return
        fi
    fi
    
    # Generate 32-character random password
    if command -v openssl >/dev/null 2>&1; then
        openssl rand -base64 32 | tr -d '\n' > "$file_path"
    elif command -v pwgen >/dev/null 2>&1; then
        pwgen -s 32 1 > "$file_path"
    else
        # Fallback: use /dev/urandom
        head -c 32 /dev/urandom | base64 | tr -d '\n' > "$file_path"
    fi
    chmod 600 "$file_path"
    echo "✓ Generated random password for $secret_name"
}

# Ask user preference
echo "How would you like to set passwords?"
echo "1) Enter passwords interactively (most secure)"
echo "2) Generate random passwords automatically"
read -p "Enter choice (1 or 2): " choice

case $choice in
    1)
        echo ""
        echo "Enter passwords (they will not be displayed):"
        create_secret "mysql_root_password" "MySQL root password"
        create_secret "mysql_password" "MySQL slurm user password"
        create_secret "root_password" "Root user SSH password"
        create_secret "wunmi_password" "Wunmi user SSH password"
        ;;
    2)
        echo ""
        echo "Generating random passwords..."
        generate_random_secret "mysql_root_password"
        generate_random_secret "mysql_password"
        generate_random_secret "root_password"
        generate_random_secret "wunmi_password"
        echo ""
        echo "Random passwords generated! To view them, use:"
        echo "  cat secrets/mysql_root_password.txt"
        echo "  cat secrets/mysql_password.txt"
        echo "  cat secrets/root_password.txt"
        echo "  cat secrets/wunmi_password.txt"
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac

echo ""
echo "=============================================="
echo "✓ All secrets created successfully!"
echo ""
echo "Secret files created in: $SECRETS_DIR"
echo "File permissions set to 600 (read/write for owner only)"
echo ""
echo "Next steps:"
echo "1. Review the secrets if needed"
echo "2. Deploy with: docker-compose up -d"
echo ""

