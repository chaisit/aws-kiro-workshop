#!/bin/bash -xe
exec > /var/log/userdata-kiro-lab.log 2>&1

echo "=== Kiro-LAB Instance Setup ==="
echo "Started at: $(date)"

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
# Node.js (LTS via NodeSource)
# ----------------------------
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs
npm install -g npm@latest || true  # May fail if npm version requires newer Node.js

# ----------------------------
# Bun
# ----------------------------
curl -fsSL https://bun.sh/install | bash
ln -sf /root/.bun/bin/bun /usr/local/bin/bun
ln -sf /root/.bun/bin/bunx /usr/local/bin/bunx
# Also install for ubuntu user
su - ubuntu -c "curl -fsSL https://bun.sh/install | bash"

# ----------------------------
# uv + uvx (Python package manager)
# ----------------------------
curl -LsSf https://astral.sh/uv/install.sh | sh
ln -sf /root/.local/bin/uv /usr/local/bin/uv
ln -sf /root/.local/bin/uvx /usr/local/bin/uvx
# Also install for ubuntu user
su - ubuntu -c "curl -LsSf https://astral.sh/uv/install.sh | sh"

# ----------------------------
# graphify (via uv tool)
# ----------------------------
su - ubuntu -c "/home/ubuntu/.local/bin/uv tool install graphify"

# ----------------------------
# AWS CLI v2
# ----------------------------
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
unzip -q /tmp/awscliv2.zip -d /tmp
/tmp/aws/install
rm -rf /tmp/aws /tmp/awscliv2.zip

# ----------------------------
# Clone workshop repository
# ----------------------------
su - ubuntu -c "git clone https://git.rmutsv.app/kai/aws-academy-kiro-workshop.git /home/ubuntu/workshop"

# ----------------------------
# Setup Kiro MCP support
# ----------------------------
# Create .kiro directory structure for ubuntu user
su - ubuntu -c "mkdir -p /home/ubuntu/.kiro/settings"

# Create global MCP config with aws-docs server
cat > /home/ubuntu/.kiro/settings/mcp.json << 'EOF'
{
  "mcpServers": {
    "aws-docs": {
      "command": "uvx",
      "args": ["awslabs.aws-documentation-mcp-server@latest"],
      "env": {
        "FASTMCP_LOG_LEVEL": "ERROR"
      },
      "disabled": false
    }
  }
}
EOF
chown -R ubuntu:ubuntu /home/ubuntu/.kiro

# ----------------------------
# Configure shell environment for ubuntu user
# ----------------------------
cat >> /home/ubuntu/.bashrc << 'EOF'

# Kiro-LAB environment
export PATH="$HOME/.local/bin:$HOME/.bun/bin:$PATH"

# uv/uvx completions
eval "$(uv generate-shell-completion bash 2>/dev/null || true)"
EOF

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
