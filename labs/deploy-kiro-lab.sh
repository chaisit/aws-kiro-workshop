#!/bin/bash
# =============================================================================
# deploy-kiro-lab.sh
# Deploys an EC2 instance (Kiro-LAB) for remote SSH development with Kiro IDE
#
# Usage:
#   curl -fsSL https://github.com/chaisit/aws-kiro-workshop/raw/refs/heads/main/labs/deploy-kiro-lab.sh | bash
#   -- or --
#   bash deploy-kiro-lab.sh
#
# Prerequisites:
#   - AWS CLI configured with valid credentials
#   - Key pair 'vockey' exists in your AWS account
#   - vockey.pem key file available (script will prompt for path)
# =============================================================================

set -euo pipefail

# ─── Configuration ───────────────────────────────────────────────────────────
INSTANCE_NAME="Kiro-LAB"
KEY_NAME="vockey"
INSTANCE_TYPE="t3.medium"
VOLUME_SIZE=30
REGION="${AWS_DEFAULT_REGION:-us-east-1}"
SSH_CONFIG_HOST="kiro-lab"
USERDATA_URL="https://github.com/chaisit/aws-kiro-workshop/raw/refs/heads/main/labs/userdata-kiro-lab.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ─── Functions ───────────────────────────────────────────────────────────────

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

collect_aws_credentials() {
    echo ""
    info "─── AWS Lab Credentials Setup ───"
    echo ""
    echo "  Paste your AWS credentials from the AWS Academy Lab page."
    echo "  (Click 'AWS Details' → 'Show' next to AWS CLI credentials)"
    echo ""

    # Check if credentials are already valid
    if aws sts get-caller-identity &> /dev/null; then
        ok "AWS credentials already configured and valid."
        read -rp "  Do you want to reconfigure? [y/N]: " reconfigure
        if [[ ! "$reconfigure" =~ ^[Yy]$ ]]; then
            return 0
        fi
    fi

    # Prompt for credentials
    read -rp "  aws_access_key_id: " aws_key_id
    read -rp "  aws_secret_access_key: " aws_secret_key
    read -rp "  aws_session_token: " aws_session_token

    if [[ -z "$aws_key_id" || -z "$aws_secret_key" || -z "$aws_session_token" ]]; then
        error "All three credential fields are required."
        exit 1
    fi

    # Export as environment variables for this session
    export AWS_ACCESS_KEY_ID="$aws_key_id"
    export AWS_SECRET_ACCESS_KEY="$aws_secret_key"
    export AWS_SESSION_TOKEN="$aws_session_token"
    export AWS_DEFAULT_REGION="${REGION}"

    # Verify credentials work
    if ! aws sts get-caller-identity &> /dev/null; then
        error "Credentials are invalid or expired. Please check and try again."
        exit 1
    fi

    ok "AWS credentials configured. Account: $(aws sts get-caller-identity --query Account --output text)"
}

collect_ssh_key() {
    echo ""
    info "─── SSH Private Key Setup ───"
    echo ""

    local ssh_dir="$HOME/.ssh"
    local key_file="$ssh_dir/vockey.pem"

    # Check if key already exists
    if [[ -f "$key_file" ]]; then
        ok "SSH key already exists: $key_file"
        read -rp "  Do you want to replace it? [y/N]: " replace_key
        if [[ ! "$replace_key" =~ ^[Yy]$ ]]; then
            SSH_KEY_PATH="$key_file"
            return 0
        fi
    fi

    # Search common locations first
    local search_paths=(
        "./vockey.pem"
        "./aws-credentials/vockey.pem"
        "$HOME/Downloads/vockey.pem"
        "$HOME/labsuser.pem"
    )

    for path in "${search_paths[@]}"; do
        if [[ -f "$path" ]]; then
            SSH_KEY_PATH="$(realpath "$path")"
            ok "Found existing SSH key: $SSH_KEY_PATH"
            return 0
        fi
    done

    echo "  Paste your SSH private key (vockey.pem) from AWS Academy Lab."
    echo "  (Click 'AWS Details' → 'Show' next to SSH Key)"
    echo ""
    echo "  Paste the key below (including BEGIN/END lines), then press Enter on an empty line:"
    echo ""

    # Read multi-line key input
    mkdir -p "$ssh_dir"
    local key_content=""
    local line

    while IFS= read -r line; do
        # Stop on empty line after we have content
        if [[ -z "$line" && -n "$key_content" ]]; then
            break
        fi
        key_content+="$line"$'\n'
    done

    # Validate it looks like a private key
    if [[ ! "$key_content" == *"BEGIN"*"PRIVATE KEY"* ]]; then
        error "Input does not appear to be a valid private key."
        exit 1
    fi

    # Write key file
    echo -n "$key_content" > "$key_file"
    chmod 400 "$key_file"

    SSH_KEY_PATH="$key_file"
    ok "SSH key saved: $SSH_KEY_PATH"
}

install_aws_cli() {
    info "AWS CLI not found. Installing..."

    local os_type
    os_type="$(uname -s)"

    case "$os_type" in
        Darwin)
            # macOS
            local pkg_url="https://awscli.amazonaws.com/AWSCLIV2.pkg"
            local pkg_file="/tmp/AWSCLIV2.pkg"
            info "Downloading AWS CLI for macOS..."
            curl -fsSL "$pkg_url" -o "$pkg_file"
            sudo installer -pkg "$pkg_file" -target /
            rm -f "$pkg_file"
            ;;
        Linux)
            # Linux
            local zip_url="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
            local zip_file="/tmp/awscliv2.zip"
            info "Downloading AWS CLI for Linux..."
            curl -fsSL "$zip_url" -o "$zip_file"
            unzip -qo "$zip_file" -d /tmp
            sudo /tmp/aws/install --update
            rm -rf /tmp/aws "$zip_file"
            ;;
        *)
            error "Unsupported OS: $os_type. Please install AWS CLI manually."
            echo "  https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
            exit 1
            ;;
    esac

    # Verify installation
    if ! command -v aws &> /dev/null; then
        error "AWS CLI installation failed. Please install manually."
        exit 1
    fi

    ok "AWS CLI installed: $(aws --version)"
}

check_prerequisites() {
    info "Checking prerequisites..."

    # Install AWS CLI if not present
    if ! command -v aws &> /dev/null; then
        install_aws_cli
    else
        ok "AWS CLI found: $(aws --version 2>&1 | head -1)"
    fi
}

get_ubuntu_ami() {
    info "Finding latest Ubuntu 26.04 AMI in $REGION..."

    # Try SSM parameter for Ubuntu 26.04
    AMI_ID=$(aws ssm get-parameters \
        --names /aws/service/canonical/ubuntu/server/26.04/stable/current/amd64/hvm/ebs-gp3/ami-id \
        --region "$REGION" \
        --query 'Parameters[0].Value' \
        --output text 2>/dev/null || echo "")

    if [[ -z "$AMI_ID" || "$AMI_ID" == "None" ]]; then
        # Fallback: search for Ubuntu 26.04 by name pattern
        AMI_ID=$(aws ec2 describe-images \
            --owners 099720109477 \
            --filters "Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-*-26.04-amd64-server-*" \
            --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
            --region "$REGION" \
            --output text 2>/dev/null || echo "")
    fi

    if [[ -z "$AMI_ID" || "$AMI_ID" == "None" ]]; then
        # Fallback: Ubuntu 24.04 if 26.04 not available yet
        warn "Ubuntu 26.04 not found, falling back to 24.04..."
        AMI_ID=$(aws ssm get-parameters \
            --names /aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id \
            --region "$REGION" \
            --query 'Parameters[0].Value' \
            --output text 2>/dev/null || echo "")

        if [[ -z "$AMI_ID" || "$AMI_ID" == "None" ]]; then
            AMI_ID=$(aws ec2 describe-images \
                --owners 099720109477 \
                --filters "Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*" \
                --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
                --region "$REGION" \
                --output text 2>/dev/null || echo "")
        fi
    fi

    if [[ -z "$AMI_ID" || "$AMI_ID" == "None" ]]; then
        error "Could not find Ubuntu AMI in region $REGION"
        exit 1
    fi

    ok "AMI: $AMI_ID"
}

create_security_group() {
    info "Setting up security group..."

    local sg_name="kiro-lab-sg"

    # Check if security group already exists
    SG_ID=$(aws ec2 describe-security-groups \
        --filters "Name=group-name,Values=$sg_name" \
        --query 'SecurityGroups[0].GroupId' \
        --region "$REGION" \
        --output text 2>/dev/null || echo "None")

    if [[ "$SG_ID" != "None" && -n "$SG_ID" ]]; then
        ok "Security group already exists: $SG_ID"
        return 0
    fi

    # Create security group in default VPC
    SG_ID=$(aws ec2 create-security-group \
        --group-name "$sg_name" \
        --description "Security group for Kiro-LAB SSH development instance" \
        --region "$REGION" \
        --output text --query 'GroupId')

    # Allow SSH from anywhere (for lab purposes)
    aws ec2 authorize-security-group-ingress \
        --group-id "$SG_ID" \
        --protocol tcp \
        --port 22 \
        --cidr 0.0.0.0/0 \
        --region "$REGION" > /dev/null

    ok "Created security group: $SG_ID (SSH inbound only)"
}

get_userdata() {
    # Try to download from URL, fallback to local file
    local userdata_file="/tmp/kiro-lab-userdata.sh"

    if [[ -f "$(dirname "$0")/userdata-kiro-lab.sh" ]]; then
        userdata_file="$(dirname "$0")/userdata-kiro-lab.sh"
        info "Using local userdata script"
    elif curl -fsSL "$USERDATA_URL" -o "$userdata_file" 2>/dev/null; then
        info "Downloaded userdata from remote"
    else
        # Inline minimal userdata
        warn "Could not fetch userdata script, using embedded version"
        cat > "$userdata_file" << 'USERDATA'
#!/bin/bash -xe
exec > /var/log/userdata-kiro-lab.log 2>&1
apt update -y && apt upgrade -y
apt install -y build-essential curl wget unzip git python3 python3-pip python3-venv
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs
npm install -g npm@latest
curl -fsSL https://bun.sh/install | bash
ln -sf /root/.bun/bin/bun /usr/local/bin/bun
ln -sf /root/.bun/bin/bunx /usr/local/bin/bunx
su - ubuntu -c "curl -fsSL https://bun.sh/install | bash"
curl -LsSf https://astral.sh/uv/install.sh | sh
ln -sf /root/.local/bin/uv /usr/local/bin/uv
ln -sf /root/.local/bin/uvx /usr/local/bin/uvx
su - ubuntu -c "curl -LsSf https://astral.sh/uv/install.sh | sh"
su - ubuntu -c "/home/ubuntu/.local/bin/uv tool install graphify"
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
unzip -q /tmp/awscliv2.zip -d /tmp && /tmp/aws/install && rm -rf /tmp/aws /tmp/awscliv2.zip
su - ubuntu -c "git clone https://github.com/chaisit/aws-kiro-workshop.git /home/ubuntu/workshop"
su - ubuntu -c "mkdir -p /home/ubuntu/.kiro/settings"
cat > /home/ubuntu/.kiro/settings/mcp.json << 'EOF'
{"mcpServers":{"aws-docs":{"command":"uvx","args":["awslabs.aws-documentation-mcp-server@latest"],"env":{"FASTMCP_LOG_LEVEL":"ERROR"},"disabled":false}}}
EOF
chown -R ubuntu:ubuntu /home/ubuntu/.kiro
cat >> /home/ubuntu/.bashrc << 'EOF'
export PATH="$HOME/.local/bin:$HOME/.bun/bin:$PATH"
EOF
hostnamectl set-hostname kiro-lab
touch /home/ubuntu/.kiro-lab-ready && chown ubuntu:ubuntu /home/ubuntu/.kiro-lab-ready
USERDATA
    fi

    USERDATA_PATH="$userdata_file"
}

launch_instance() {
    info "Launching EC2 instance ($INSTANCE_TYPE)..."

    INSTANCE_ID=$(aws ec2 run-instances \
        --image-id "$AMI_ID" \
        --instance-type "$INSTANCE_TYPE" \
        --key-name "$KEY_NAME" \
        --security-group-ids "$SG_ID" \
        --iam-instance-profile Name=LabInstanceProfile \
        --block-device-mappings "DeviceName=/dev/sda1,Ebs={VolumeSize=$VOLUME_SIZE,VolumeType=gp3,Encrypted=true}" \
        --user-data "file://$USERDATA_PATH" \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
        --region "$REGION" \
        --query 'Instances[0].InstanceId' \
        --output text)

    ok "Instance launched: $INSTANCE_ID"

    info "Waiting for instance to enter running state..."
    aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$REGION"
    ok "Instance is running!"
}

get_instance_dns() {
    info "Getting instance public DNS name..."

    # Wait a moment for DNS to propagate
    sleep 5

    PUBLIC_DNS=$(aws ec2 describe-instances \
        --instance-ids "$INSTANCE_ID" \
        --query 'Reservations[0].Instances[0].PublicDnsName' \
        --region "$REGION" \
        --output text)

    PUBLIC_IP=$(aws ec2 describe-instances \
        --instance-ids "$INSTANCE_ID" \
        --query 'Reservations[0].Instances[0].PublicIpAddress' \
        --region "$REGION" \
        --output text)

    if [[ -z "$PUBLIC_DNS" || "$PUBLIC_DNS" == "None" ]]; then
        warn "No public DNS assigned. Using public IP: $PUBLIC_IP"
        PUBLIC_DNS="$PUBLIC_IP"
    fi

    ok "Public DNS: $PUBLIC_DNS"
    ok "Public IP:  $PUBLIC_IP"
}

configure_ssh() {
    info "Configuring SSH..."

    local ssh_dir="$HOME/.ssh"
    local ssh_config="$ssh_dir/config"

    # Ensure .ssh directory exists
    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"

    # Fix key permissions
    chmod 400 "$SSH_KEY_PATH"

    # Remove old kiro-lab entry if exists
    if [[ -f "$ssh_config" ]]; then
        # Remove existing block
        sed -i.bak '/^# >>> Kiro-LAB >>>/,/^# <<< Kiro-LAB <<</d' "$ssh_config"
    fi

    # Append new SSH config entry (quote IdentityFile path to handle spaces)
    cat >> "$ssh_config" << EOF

# >>> Kiro-LAB >>>
Host $SSH_CONFIG_HOST
    HostName $PUBLIC_DNS
    User ubuntu
    IdentityFile "$SSH_KEY_PATH"
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel ERROR
    ServerAliveInterval 60
    ServerAliveCountMax 10
# <<< Kiro-LAB <<<
EOF

    chmod 600 "$ssh_config"
    ok "SSH config updated: ~/.ssh/config"
    echo ""
    echo "  You can now connect with:  ssh $SSH_CONFIG_HOST"
}

print_summary() {
    echo ""
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Kiro-LAB Instance Deployed Successfully!${NC}"
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "  Instance ID:   $INSTANCE_ID"
    echo "  Public DNS:    $PUBLIC_DNS"
    echo "  Public IP:     $PUBLIC_IP"
    echo "  Instance Type: $INSTANCE_TYPE"
    echo "  Region:        $REGION"
    echo ""
    echo -e "${BLUE}  SSH Command:${NC}    ssh $SSH_CONFIG_HOST"
    echo -e "${BLUE}  SSH Config:${NC}     Host '$SSH_CONFIG_HOST' added to ~/.ssh/config"
    echo ""
    echo -e "${YELLOW}  NOTE: The instance is still running userdata setup (~3-5 min).${NC}"
    echo -e "${YELLOW}  Check progress:  ssh $SSH_CONFIG_HOST 'tail -f /var/log/userdata-kiro-lab.log'${NC}"
    echo -e "${YELLOW}  Check ready:     ssh $SSH_CONFIG_HOST 'ls ~/.kiro-lab-ready 2>/dev/null && echo READY'${NC}"
    echo ""
    echo "  ─── Kiro Remote SSH Setup ───"
    echo "  1. Open Kiro IDE"
    echo "  2. Install 'Remote - SSH' extension (if not already)"
    echo "  3. Ctrl+Shift+P → 'Remote-SSH: Connect to Host...'"
    echo "  4. Select '$SSH_CONFIG_HOST'"
    echo "  5. Open folder: /home/ubuntu/workshop"
    echo ""
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
}

# ─── Main ────────────────────────────────────────────────────────────────────

main() {
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║   Kiro-LAB EC2 Instance Deployment       ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
    echo ""

    check_prerequisites
    collect_aws_credentials
    collect_ssh_key
    get_ubuntu_ami
    create_security_group
    get_userdata
    launch_instance
    get_instance_dns
    configure_ssh
    print_summary
}

main "$@"
