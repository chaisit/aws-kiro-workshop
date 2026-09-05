#!/bin/bash -x
exec > /var/log/userdata-kiro-lab.log 2>&1

echo "=== Kiro-LAB Instance Setup ==="
echo "Started at: $(date)"

# Ensure HOME is set (cloud-init sometimes doesn't set it)
export HOME="${HOME:-/root}"

# Run apt non-interactively (avoid prompts that stall the boot-time script)
export DEBIAN_FRONTEND=noninteractive

# ----------------------------
# Resilience helpers
# The most common userdata failure on AWS is apt hanging or failing because
# the network isn't ready yet, a mirror is briefly unreachable, or cloud-init /
# unattended-upgrades still holds the apt/dpkg lock at boot. These helpers add
# retries, timeouts, and lock-waiting so the script survives transient issues.
# ----------------------------

# Wait until outbound network + APT mirror is reachable (max ~2.5 min)
wait_for_network() {
    echo "Waiting for network connectivity..."
    for i in $(seq 1 30); do
        if curl -fsSL --max-time 10 http://archive.ubuntu.com >/dev/null 2>&1 \
            || curl -fsSL --max-time 10 https://deb.nodesource.com >/dev/null 2>&1; then
            echo "Network is reachable (attempt $i)."
            return 0
        fi
        echo "Network not ready yet (attempt $i/30), retrying in 5s..."
        sleep 5
    done
    echo "WARNING: network still not confirmed after retries; continuing anyway."
    return 0
}

# Wait for apt/dpkg locks to be released (cloud-init / unattended-upgrades)
wait_for_apt_lock() {
    echo "Waiting for apt/dpkg locks to be released..."
    for i in $(seq 1 60); do
        if ! fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 \
            && ! fuser /var/lib/apt/lists/lock >/dev/null 2>&1 \
            && ! fuser /var/lib/dpkg/lock >/dev/null 2>&1; then
            return 0
        fi
        echo "apt/dpkg is locked (attempt $i/60), waiting 5s..."
        sleep 5
    done
    echo "WARNING: apt/dpkg still locked after waiting; continuing anyway."
    return 0
}

# Run an apt command with retries and a hard timeout so it can never hang forever
apt_retry() {
    local attempt
    for attempt in 1 2 3 4 5; do
        wait_for_apt_lock
        echo "Running: apt-get $* (attempt $attempt/5)"
        if timeout 600 apt-get -o Acquire::Retries=3 -y "$@"; then
            return 0
        fi
        echo "apt-get $* failed (attempt $attempt/5), retrying in 15s..."
        sleep 15
    done
    echo "ERROR: 'apt-get $*' failed after 5 attempts."
    return 1
}

wait_for_network

# Update system
apt_retry update
apt_retry upgrade

# Install essential build tools
apt_retry install \
  build-essential \
  curl \
  wget \
  unzip \
  git \
  ca-certificates \
  gnupg \
  python3 \
  python3-pip \
  python3-venv \
  software-properties-common

# ----------------------------
# Node.js 22 LTS (via NodeSource)
# ----------------------------
curl -fsSL --retry 3 --retry-delay 5 https://deb.nodesource.com/setup_22.x | bash -
apt_retry install nodejs
npm install -g npm@latest || true  # May fail if npm version requires newer Node.js

# ----------------------------
# Bun (install for ubuntu user, then symlink to /usr/local/bin)
# ----------------------------
su - ubuntu -c "export BUN_INSTALL=/home/ubuntu/.bun && curl -fsSL --retry 3 --retry-delay 5 https://bun.sh/install | bash" || true
# Make bun available system-wide by symlinking from ubuntu's install
ln -sf /home/ubuntu/.bun/bin/bun /usr/local/bin/bun 2>/dev/null || true
ln -sf /home/ubuntu/.bun/bin/bun /usr/local/bin/bunx 2>/dev/null || true

# ----------------------------
# uv + uvx (Python package manager)
# ----------------------------
curl -LsSf --retry 3 --retry-delay 5 https://astral.sh/uv/install.sh | sh || true
ln -sf /root/.local/bin/uv /usr/local/bin/uv 2>/dev/null || true
ln -sf /root/.local/bin/uvx /usr/local/bin/uvx 2>/dev/null || true
# Also install for ubuntu user
su - ubuntu -c "curl -LsSf --retry 3 --retry-delay 5 https://astral.sh/uv/install.sh | sh" || true

# ----------------------------
# graphify (via uv tool)
# ----------------------------
su - ubuntu -c "/home/ubuntu/.local/bin/uv tool install graphifyy" || true

# ----------------------------
# AWS CLI v2
# ----------------------------
if ! command -v aws &> /dev/null; then
    curl -fsSL --retry 3 --retry-delay 5 "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
    unzip -q /tmp/awscliv2.zip -d /tmp
    /tmp/aws/install
    rm -rf /tmp/aws /tmp/awscliv2.zip
fi

# ----------------------------
# Clone workshop repository
# ----------------------------
if [[ ! -d /home/ubuntu/workshop ]]; then
    git clone https://github.com/chaisit/aws-kiro-workshop.git /home/ubuntu/workshop
    chown -R ubuntu:ubuntu /home/ubuntu/workshop
fi

# ----------------------------
# Setup Kiro MCP support
# ----------------------------
su - ubuntu -c "mkdir -p /home/ubuntu/.kiro/settings"

# Write MCP config with full path to uvx (Kiro Remote SSH doesn't load .bashrc PATH)
cat > /home/ubuntu/.kiro/settings/mcp.json << 'EOF'
{
  "mcpServers": {
    "aws-docs": {
      "command": "/home/ubuntu/.local/bin/uvx",
      "args": ["awslabs.aws-documentation-mcp-server@latest"],
      "env": { "FASTMCP_LOG_LEVEL": "ERROR" },
      "disabled": false
    },
    "awsiac": {
      "command": "/home/ubuntu/.local/bin/uvx",
      "args": [
        "--from",
        "awslabs.aws-iac-mcp-server@latest",
        "--with",
        "fastmcp>=3.2.0,<4.0",
        "awslabs.aws-iac-mcp-server"
      ],
      "env": { "FASTMCP_LOG_LEVEL": "ERROR" },
      "disabled": false
    },
    "awsknowledge": {
      "url": "https://knowledge-mcp.global.api.aws"
    },
    "awspricing": {
      "command": "/home/ubuntu/.local/bin/uvx",
      "args": ["awslabs.aws-pricing-mcp-server@latest"],
      "env": { "FASTMCP_LOG_LEVEL": "ERROR" }
    }
  }
}
EOF
chown -R ubuntu:ubuntu /home/ubuntu/.kiro

# ----------------------------
# Configure shell environment for ubuntu user
# ----------------------------
if ! grep -q "Kiro-LAB environment" /home/ubuntu/.bashrc 2>/dev/null; then
    cat >> /home/ubuntu/.bashrc << 'EOF'

# Kiro-LAB environment
export PATH="$HOME/.local/bin:$HOME/.bun/bin:$PATH"

# uv/uvx completions
eval "$(uv generate-shell-completion bash 2>/dev/null || true)"
EOF
fi

# ----------------------------
# Enable SSH TCP forwarding (required for Kiro Remote-SSH port forwarding)
# Use a drop-in file so it survives sshd_config updates and stays idempotent.
# ----------------------------
mkdir -p /etc/ssh/sshd_config.d
cat > /etc/ssh/sshd_config.d/60-kiro-lab.conf << 'EOF'
AllowTcpForwarding yes
EOF
systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || true

# ----------------------------
# Set hostname
# ----------------------------
hostnamectl set-hostname kiro-lab

# ----------------------------
# Create a ready marker
# ----------------------------
touch /home/ubuntu/.kiro-lab-ready
chown ubuntu:ubuntu /home/ubuntu/.kiro-lab-ready

echo "=== Kiro-LAB Setup Complete ==="
echo "Finished at: $(date)"
