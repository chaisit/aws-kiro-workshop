#!/bin/bash -x
exec > /var/log/userdata-kiro-lab.log 2>&1

echo "=== Kiro-LAB Instance Setup (Amazon Linux 2023) ==="
echo "Started at: $(date)"

# Ensure HOME is set (cloud-init sometimes doesn't set it)
export HOME="${HOME:-/root}"

# Amazon Linux uses ec2-user as the default login user (not "ubuntu")
LAB_USER="ec2-user"
LAB_HOME="/home/${LAB_USER}"

# ----------------------------
# Resilience helpers
# A common userdata failure on AWS is the package manager hanging or failing
# because the network isn't ready yet or a mirror is briefly unreachable.
# dnf on Amazon Linux 2023 does not suffer from the boot-time apt/dpkg lock
# contention that Ubuntu does, but we still add network waiting, retries, and a
# hard timeout so the script survives transient issues.
# ----------------------------

# Wait until outbound network + a package mirror is reachable (max ~2.5 min)
wait_for_network() {
    echo "Waiting for network connectivity..."
    for i in $(seq 1 30); do
        if curl -fsSL --max-time 10 https://amazonlinux.default.amazonaws.com >/dev/null 2>&1 \
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

# Run a dnf command with retries and a hard timeout so it can never hang forever
dnf_retry() {
    local attempt
    for attempt in 1 2 3 4 5; do
        echo "Running: dnf $* (attempt $attempt/5)"
        if timeout 600 dnf -y "$@"; then
            return 0
        fi
        echo "dnf $* failed (attempt $attempt/5), retrying in 15s..."
        sleep 15
    done
    echo "ERROR: 'dnf $*' failed after 5 attempts."
    return 1
}

# Run a command as the lab user
as_user() {
    su - "$LAB_USER" -c "$1"
}

wait_for_network

# ----------------------------
# Update system
# ----------------------------
dnf_retry upgrade --releasever=latest

# ----------------------------
# Essential build tools
# ("Development Tools" group replaces Ubuntu's build-essential)
# ----------------------------
dnf_retry groupinstall "Development Tools"
dnf_retry install \
  curl \
  wget \
  unzip \
  git \
  tar \
  gzip \
  ca-certificates \
  gnupg2 \
  python3 \
  python3-pip

# ----------------------------
# Node.js 22 LTS (via NodeSource RPM setup)
# ----------------------------
curl -fsSL --retry 3 --retry-delay 5 https://rpm.nodesource.com/setup_22.x | bash -
dnf_retry install nodejs
npm install -g npm@latest || true  # May fail if npm version requires newer Node.js

# ----------------------------
# Bun (install for ec2-user, then symlink to /usr/local/bin)
# ----------------------------
as_user "export BUN_INSTALL=${LAB_HOME}/.bun && curl -fsSL --retry 3 --retry-delay 5 https://bun.sh/install | bash" || true
ln -sf "${LAB_HOME}/.bun/bin/bun" /usr/local/bin/bun 2>/dev/null || true
ln -sf "${LAB_HOME}/.bun/bin/bun" /usr/local/bin/bunx 2>/dev/null || true

# ----------------------------
# uv + uvx (Python package manager)
# ----------------------------
curl -LsSf --retry 3 --retry-delay 5 https://astral.sh/uv/install.sh | sh || true
ln -sf /root/.local/bin/uv /usr/local/bin/uv 2>/dev/null || true
ln -sf /root/.local/bin/uvx /usr/local/bin/uvx 2>/dev/null || true
# Also install for the lab user
as_user "curl -LsSf --retry 3 --retry-delay 5 https://astral.sh/uv/install.sh | sh" || true

# ----------------------------
# graphify (via uv tool)
# ----------------------------
as_user "${LAB_HOME}/.local/bin/uv tool install graphify" || true

# ----------------------------
# AWS CLI v2 (pre-installed on Amazon Linux 2023, install only if missing)
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
if [[ ! -d ${LAB_HOME}/workshop ]]; then
    git clone https://github.com/chaisit/aws-kiro-workshop.git ${LAB_HOME}/workshop
    chown -R ${LAB_USER}:${LAB_USER} ${LAB_HOME}/workshop
fi

# ----------------------------
# Setup Kiro MCP support
# ----------------------------
as_user "mkdir -p ${LAB_HOME}/.kiro/settings"

# Write MCP config with full path to uvx (Kiro Remote SSH doesn't load .bashrc PATH)
cat > ${LAB_HOME}/.kiro/settings/mcp.json << EOF
{
  "mcpServers": {
    "aws-docs": {
      "command": "${LAB_HOME}/.local/bin/uvx",
      "args": ["awslabs.aws-documentation-mcp-server@latest"],
      "env": { "FASTMCP_LOG_LEVEL": "ERROR" },
      "disabled": false
    },
    "awsiac": {
      "command": "${LAB_HOME}/.local/bin/uvx",
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
      "command": "${LAB_HOME}/.local/bin/uvx",
      "args": ["awslabs.aws-pricing-mcp-server@latest"],
      "env": { "FASTMCP_LOG_LEVEL": "ERROR" }
    }
  }
}
EOF
chown -R ${LAB_USER}:${LAB_USER} ${LAB_HOME}/.kiro

# ----------------------------
# Configure shell environment for the lab user
# ----------------------------
if ! grep -q "Kiro-LAB environment" ${LAB_HOME}/.bashrc 2>/dev/null; then
    cat >> ${LAB_HOME}/.bashrc << 'EOF'

# Kiro-LAB environment
export PATH="$HOME/.local/bin:$HOME/.bun/bin:$PATH"

# uv/uvx completions
eval "$(uv generate-shell-completion bash 2>/dev/null || true)"
EOF
fi

# ----------------------------
# Set hostname
# ----------------------------
hostnamectl set-hostname kiro-lab

# ----------------------------
# Create a ready marker
# ----------------------------
touch ${LAB_HOME}/.kiro-lab-ready
chown ${LAB_USER}:${LAB_USER} ${LAB_HOME}/.kiro-lab-ready

echo "=== Kiro-LAB Setup Complete ==="
echo "Finished at: $(date)"
