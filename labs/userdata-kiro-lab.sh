#!/bin/bash -x
exec > /var/log/userdata-kiro-lab.log 2>&1

echo "=== Kiro-LAB Instance Setup ==="
echo "Started at: $(date)"

# Ensure HOME is set (cloud-init sometimes doesn't set it)
export HOME="${HOME:-/root}"

# Update system
apt update -y
apt upgrade -y

# Install essential build tools
apt install -y \
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
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt install -y nodejs
npm install -g npm@latest || true  # May fail if npm version requires newer Node.js

# ----------------------------
# Bun (install for ubuntu user, then symlink to /usr/local/bin)
# ----------------------------
su - ubuntu -c "export BUN_INSTALL=/home/ubuntu/.bun && curl -fsSL https://bun.sh/install | bash" || true
# Make bun available system-wide by symlinking from ubuntu's install
ln -sf /home/ubuntu/.bun/bin/bun /usr/local/bin/bun 2>/dev/null || true
ln -sf /home/ubuntu/.bun/bin/bun /usr/local/bin/bunx 2>/dev/null || true

# ----------------------------
# uv + uvx (Python package manager)
# ----------------------------
curl -LsSf https://astral.sh/uv/install.sh | sh || true
ln -sf /root/.local/bin/uv /usr/local/bin/uv 2>/dev/null || true
ln -sf /root/.local/bin/uvx /usr/local/bin/uvx 2>/dev/null || true
# Also install for ubuntu user
su - ubuntu -c "curl -LsSf https://astral.sh/uv/install.sh | sh" || true

# ----------------------------
# graphify (via uv tool — package name is "graphifyy")
# ----------------------------
su - ubuntu -c "/home/ubuntu/.local/bin/uv tool install graphifyy" || true

# ----------------------------
# AWS CLI v2
# ----------------------------
if ! command -v aws &> /dev/null; then
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
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
