#!/bin/bash
# Don't use strict error handling - we want to handle munge errors gracefully
set +e

ROLE="${ROLE:-controller}"

# --- Runtime secret handling ---
# Read Docker secrets FIRST (before rendering templates that need these values)
# If Docker secrets are mounted at /run/secrets, prefer them over env vars.
# This is useful when the stack runs in swarm mode with secrets configured.
if [ -f /run/secrets/mysql_password ]; then
    export MYSQL_PASSWORD="$(cat /run/secrets/mysql_password)"
    echo "Using MYSQL_PASSWORD from Docker secret"
fi
if [ -f /run/secrets/mysql_root_password ]; then
    export MYSQL_ROOT_PASSWORD="$(cat /run/secrets/mysql_root_password)"
    echo "Using MYSQL_ROOT_PASSWORD from Docker secret"
fi
if [ -f /run/secrets/root_password ]; then
    export ROOT_PASSWORD="$(cat /run/secrets/root_password)"
    echo "Using ROOT_PASSWORD from Docker secret"
fi
if [ -f /run/secrets/wunmi_password ]; then
    export WUNMI_PASSWORD="$(cat /run/secrets/wunmi_password)"
    echo "Using WUNMI_PASSWORD from Docker secret"
fi

# Set system user passwords (after reading secrets)
if [ -n "$ROOT_PASSWORD" ]; then
    echo "root:${ROOT_PASSWORD}" | chpasswd || true
fi
if [ -n "$WUNMI_PASSWORD" ]; then
    echo "wunmi:${WUNMI_PASSWORD}" | chpasswd || true
fi

# Render slurmdbd.conf from template if present. This avoids storing DB passwords
# in the image. The template can include ${MYSQL_HOST}, ${MYSQL_USER}, ${MYSQL_PASSWORD}, ${MYSQL_DATABASE}.
# NOTE: This must happen AFTER reading secrets so MYSQL_PASSWORD is available.
if [ -f /etc/slurm/slurmdbd.conf.template ]; then
    if command -v envsubst >/dev/null 2>&1; then
        echo "Rendering /etc/slurm/slurmdbd.conf from template"
        envsubst < /etc/slurm/slurmdbd.conf.template > /etc/slurm/slurmdbd.conf || true
        chown slurm:slurm /etc/slurm/slurmdbd.conf || true
        chmod 600 /etc/slurm/slurmdbd.conf || true
    else
        echo "Warning: envsubst not available; using template as-is"
        cp /etc/slurm/slurmdbd.conf.template /etc/slurm/slurmdbd.conf || true
        chown slurm:slurm /etc/slurm/slurmdbd.conf || true
        chmod 600 /etc/slurm/slurmdbd.conf || true
    fi
fi

# Create necessary directories with proper permissions
mkdir -p /var/spool/slurm/ctld /var/spool/slurm/d /var/log/slurm /var/log/slurm/accounting /var/log/slurm/jobcomp /var/run/slurm
chown -R slurm:slurm /var/spool/slurm /var/log/slurm /var/run/slurm

# Set up SSH for passwordless inter-container communication
# Copy shared SSH keys to root and wunmi users
mkdir -p /root/.ssh
if [ -f /etc/ssh/keys/id_rsa ]; then
    cp /etc/ssh/keys/id_rsa /root/.ssh/id_rsa
    cp /etc/ssh/keys/id_rsa.pub /root/.ssh/id_rsa.pub
    cp /etc/ssh/keys/id_ed25519 /root/.ssh/id_ed25519 2>/dev/null || true
    cp /etc/ssh/keys/id_ed25519.pub /root/.ssh/id_ed25519.pub 2>/dev/null || true
    chmod 700 /root/.ssh
    chmod 600 /root/.ssh/id_rsa /root/.ssh/id_ed25519 2>/dev/null || true
    chmod 644 /root/.ssh/id_rsa.pub /root/.ssh/id_ed25519.pub 2>/dev/null || true
fi

# Set up authorized_keys with shared public key for passwordless login
if [ -f /etc/ssh/keys/id_rsa.pub ]; then
    cat /etc/ssh/keys/id_rsa.pub >> /root/.ssh/authorized_keys 2>/dev/null || true
    if [ -f /etc/ssh/keys/id_ed25519.pub ]; then
        cat /etc/ssh/keys/id_ed25519.pub >> /root/.ssh/authorized_keys 2>/dev/null || true
    fi
    chmod 600 /root/.ssh/authorized_keys 2>/dev/null || true
fi

# Set up SSH for wunmi user
if id wunmi >/dev/null 2>&1; then
    mkdir -p /home/wunmi /home/wunmi/.ssh
    if [ -f /etc/ssh/keys/id_rsa ]; then
        cp /etc/ssh/keys/id_rsa /home/wunmi/.ssh/id_rsa
        cp /etc/ssh/keys/id_rsa.pub /home/wunmi/.ssh/id_rsa.pub
        cp /etc/ssh/keys/id_ed25519 /home/wunmi/.ssh/id_ed25519 2>/dev/null || true
        cp /etc/ssh/keys/id_ed25519.pub /home/wunmi/.ssh/id_ed25519.pub 2>/dev/null || true
        chown -R wunmi:wunmi /home/wunmi/.ssh 2>/dev/null || true
        chmod 700 /home/wunmi/.ssh
        chmod 600 /home/wunmi/.ssh/id_rsa /home/wunmi/.ssh/id_ed25519 2>/dev/null || true
        chmod 644 /home/wunmi/.ssh/id_rsa.pub /home/wunmi/.ssh/id_ed25519.pub 2>/dev/null || true
    fi
    if [ -f /etc/ssh/keys/id_rsa.pub ]; then
        cat /etc/ssh/keys/id_rsa.pub >> /home/wunmi/.ssh/authorized_keys 2>/dev/null || true
        if [ -f /etc/ssh/keys/id_ed25519.pub ]; then
            cat /etc/ssh/keys/id_ed25519.pub >> /home/wunmi/.ssh/authorized_keys 2>/dev/null || true
        fi
        chown wunmi:wunmi /home/wunmi/.ssh/authorized_keys 2>/dev/null || true
        chmod 600 /home/wunmi/.ssh/authorized_keys 2>/dev/null || true
    fi
    chown -R wunmi:wunmi /home/wunmi 2>/dev/null || true
    chmod 755 /home/wunmi 2>/dev/null || true
fi

# Configure known_hosts to avoid host key verification prompts
# Wait a bit for all containers to start, then scan host keys
mkdir -p /root/.ssh /home/wunmi/.ssh
sleep 2  # Give other containers time to start SSH
for host in controller slurmdbd mysql node1 node2; do
    if [ "$host" != "$(hostname)" ]; then
        # Try to get host key (with timeout to avoid hanging)
        timeout 2 ssh-keyscan -H $host 2>/dev/null >> /root/.ssh/known_hosts || true
        if id wunmi >/dev/null 2>&1; then
            timeout 2 ssh-keyscan -H $host 2>/dev/null >> /home/wunmi/.ssh/known_hosts || true
        fi
    fi
done
chmod 600 /root/.ssh/known_hosts 2>/dev/null || true
if id wunmi >/dev/null 2>&1; then
    chown wunmi:wunmi /home/wunmi/.ssh/known_hosts 2>/dev/null || true
    chmod 600 /home/wunmi/.ssh/known_hosts 2>/dev/null || true
fi

# Create and fix munge directories (bypass /var/log/munge issues)
mkdir -p /var/log/munge /var/lib/munge /run/munge /etc/munge
chown -R munge:munge /var/log/munge /var/lib/munge /run/munge /etc/munge || true
chmod 755 /var/log/munge 2>/dev/null || true
chmod 711 /var/lib/munge 2>/dev/null || true
chmod 755 /run/munge 2>/dev/null || true
chmod 700 /etc/munge 2>/dev/null || true

# Ensure munge.key has correct permissions
if [ -f /etc/munge/munge.key ]; then
    chown munge:munge /etc/munge/munge.key 2>/dev/null || true
    chmod 400 /etc/munge/munge.key 2>/dev/null || true
fi

# Start munged daemon (required for SLURM authentication)
echo "Starting munged..."
/usr/sbin/munged --force || {
    echo "Warning: munged failed to start, but continuing..."
}

# Wait a moment for munged to initialize
sleep 1

# Verify munged is running
if ! pgrep -x munged > /dev/null; then
    echo "Error: munged is not running, but continuing anyway..."
fi

# Start SSH daemon (for inter-container communication)
echo "Starting SSH daemon for inter-container access..."
mkdir -p /var/run/sshd
/usr/sbin/sshd &
SSH_PID=$!
sleep 1  # Give SSH time to start

# Start SLURM services
if [ "$ROLE" = "slurmdbd" ]; then
    echo "Starting slurmdbd..."
    # Wait for MySQL to be ready
    echo "Waiting for MySQL to be ready..."
    for i in {1..30}; do
        if mysqladmin ping -h"$MYSQL_HOST" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" --silent 2>/dev/null; then
            echo "MySQL is up - executing commands"
            break
        fi
        if [ $i -eq 30 ]; then
            echo "MySQL failed to start after 60 seconds, continuing anyway..."
            break
        fi
        echo "MySQL is unavailable - sleeping ($i/30)"
        sleep 2
    done
    
    # Initialize Slurm database schema if needed
    # Check if the database has been initialized by checking for a key table
    if mysql -h"$MYSQL_HOST" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DATABASE" -e "SHOW TABLES LIKE 'cluster_table';" 2>/dev/null | grep -q cluster_table; then
        echo "Slurm database schema already initialized"
    else
        echo "Initializing Slurm database schema..."
        # Start slurmdbd temporarily to create schema
        /usr/sbin/slurmdbd -D &
        SLURMDBD_PID=$!
        sleep 5
        
        # Initialize with sacctmgr (this will create the schema)
        echo "Creating cluster in database..."
        sacctmgr -i add cluster docker-slurm || true

        # Add root account
        echo "Creating root account..."
        sacctmgr -i add account root Cluster=docker-slurm Description="Root Account" || true

        # Add users to the root account
        echo "Adding users to cluster..."
        sacctmgr -i add user root Account=root || true
        sacctmgr -i add user wunmi Account=root || true

        # Wait a bit for schema creation
        sleep 3

        # Stop temporary slurmdbd
        if kill $SLURMDBD_PID 2>/dev/null; then
            wait $SLURMDBD_PID 2>/dev/null || true
        fi
        sleep 2
    fi
    
    echo "Starting slurmdbd (database daemon)..."
    echo "SSH is available for inter-container access (not exposed to host)"
    exec /usr/sbin/slurmdbd -Dvv
elif [ "$ROLE" = "controller" ]; then
    echo "Starting slurmctld (controller)..."
    # Wait for slurmdbd to be ready and DNS to resolve
    echo "Waiting for slurmdbd to be ready..."
    for i in {1..60}; do
        # First check if DNS resolves
        if getent hosts slurmdbd >/dev/null 2>&1; then
            # Then check if port is open
            if nc -z slurmdbd 6819 2>/dev/null; then
                echo "slurmdbd is up and accepting connections - starting slurmctld"
                break
            fi
        fi
        if [ $i -eq 60 ]; then
            echo "WARNING: slurmdbd failed to start after 120 seconds"
            echo "Attempting to start slurmctld anyway (may fail if slurmdbd is not ready)"
            break
        fi
        if [ $((i % 5)) -eq 0 ]; then
            echo "slurmdbd is unavailable - sleeping ($i/60) - checking DNS and port..."
        fi
        sleep 2
    done
    # Additional small delay to ensure slurmdbd is fully ready
    sleep 2
    echo "SSH is available for inter-container access (not exposed to host)"
    exec /usr/sbin/slurmctld -Dvv
else
    echo "Starting slurmd (compute node)..."
    echo "SSH is available for inter-container access (not exposed to host)"
    exec /usr/sbin/slurmd -Dvv
fi

