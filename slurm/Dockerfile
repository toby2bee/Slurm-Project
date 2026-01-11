FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install only runtime dependencies (no build tools or dev packages)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        slurmctld slurmd slurmdbd slurm-client \
        munge \
        openmpi-bin openmpi-common \
        python3 python3-pip \
        openssh-server openssh-client \
        default-mysql-client \
        gettext-base \
        netcat-openbsd \
        procps net-tools \
        ca-certificates && \
    # Remove unnecessary documentation and man pages
    rm -rf /usr/share/doc/* /usr/share/man/* /usr/share/info/* && \
    # Clean apt cache
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
    # Create symlink and directories
    ln -sf /usr/bin/python3 /usr/bin/python && \
    mkdir -p /var/run/sshd && \
    ssh-keygen -A

# Create users, directories, and configure SSH
# Note: Do NOT set passwords at image build time. Set at runtime via
# environment variables (ROOT_PASSWORD, WUNMI_PASSWORD) so secrets don't become
# baked into the image layers.
RUN if ! id slurm >/dev/null 2>&1; then useradd -r -m -u 64030 slurm; fi && \
    if ! id munge >/dev/null 2>&1; then useradd -r -m -u 64001 munge; fi && \
    if ! id wunmi >/dev/null 2>&1; then useradd -m -s /bin/bash wunmi; fi && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    mkdir -p \
      /etc/slurm \
      /etc/munge \
      /var/spool/slurm/ctld \
      /var/spool/slurm/d \
      /var/log/slurm \
      /var/log/munge \
      /var/lib/munge \
      /run/munge && \
    chown -R slurm:slurm /var/spool/slurm /var/log/slurm && \
    chown -R munge:munge /etc/munge /var/lib/munge /var/log/munge /run/munge && \
    chmod 711 /var/lib/munge && \
    chmod 700 /etc/munge && \
    chmod 755 /var/log/munge && \
    chmod 755 /run/munge

# Generate munge key and SSH keys in one layer
RUN dd if=/dev/urandom of=/etc/munge/munge.key bs=1024 count=1 && \
    chown munge:munge /etc/munge/munge.key && \
    chmod 400 /etc/munge/munge.key && \
    mkdir -p /etc/ssh/keys && \
    ssh-keygen -t rsa -b 4096 -f /etc/ssh/keys/id_rsa -N "" -q && \
    ssh-keygen -t ed25519 -f /etc/ssh/keys/id_ed25519 -N "" -q && \
    chmod 600 /etc/ssh/keys/id_rsa /etc/ssh/keys/id_ed25519 && \
    chmod 644 /etc/ssh/keys/id_rsa.pub /etc/ssh/keys/id_ed25519.pub

# Copy configs and entrypoint in one layer
COPY slurm.conf /etc/slurm/slurm.conf
COPY slurmdbd.conf /etc/slurm/slurmdbd.conf.template
COPY entrypoint.sh /entrypoint.sh
RUN chown slurm:slurm /etc/slurm/slurmdbd.conf.template && \
    chmod 600 /etc/slurm/slurmdbd.conf.template && \
    chmod +x /entrypoint.sh

CMD ["/entrypoint.sh"]

