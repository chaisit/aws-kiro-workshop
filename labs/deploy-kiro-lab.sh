#!/bin/bash
# =============================================================================
# deploy-kiro-lab.sh
# Deploys an EC2 instance (Kiro-LAB) for remote SSH development with Kiro IDE
#
# Usage:
#   curl -fsSL https://github.com/chaisit/aws-kiro-workshop/raw/refs/heads/main/labs/deploy-kiro-lab.sh | bash
#   -- or --
#   bash deploy-kiro-lab.sh
#   bash deploy-kiro-lab.sh --region us-west-2
#   bash deploy-kiro-lab.sh cleanup --region us-west-2
#
# Prerequisites:
#   - AWS CLI configured with valid credentials
#   - Key pair 'vockey' exists in your AWS account
#   - vockey.pem key file available (script will prompt for path)
# =============================================================================

set -euo pipefail

# ─── Argument Parsing ────────────────────────────────────────────────────────
ACTION=""
CLI_REGION=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --region|-r)
            CLI_REGION="$2"
            shift 2
            ;;
        cleanup|clean|destroy|teardown|deploy)
            ACTION="$1"
            shift
            ;;
        *)
            echo "Unknown argument: $1" >&2
            echo "Usage: bash deploy-kiro-lab.sh [deploy|cleanup] [--region REGION]" >&2
            exit 1
            ;;
    esac
done

# ─── Configuration ───────────────────────────────────────────────────────────
INSTANCE_NAME="Kiro-LAB"
KEY_NAME="vockey"
INSTANCE_TYPE="t3.medium"
VOLUME_SIZE=30
REGION="${CLI_REGION:-${AWS_DEFAULT_REGION:-us-east-1}}"
SSH_CONFIG_HOST="kiro-lab"
USERDATA_URL="https://github.com/chaisit/aws-kiro-workshop/raw/refs/heads/main/labs/userdata-kiro-lab.sh"
AWS_PROFILE_NAME="kiro-lab-deploy"

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

    # Check if profile credentials are already valid
    if aws sts get-caller-identity --profile "$AWS_PROFILE_NAME" &> /dev/null; then
        ok "AWS credentials already configured and valid (profile: $AWS_PROFILE_NAME)."
        read -rp "  Do you want to reconfigure? [y/N]: " reconfigure < /dev/tty
        if [[ ! "$reconfigure" =~ ^[Yy]$ ]]; then
            return 0
        fi
    fi

    # Credential input loop with retry on failure
    while true; do
        # Prompt for credentials
        read -rp "  aws_access_key_id: " aws_key_id < /dev/tty
        read -rp "  aws_secret_access_key: " aws_secret_key < /dev/tty
        read -rp "  aws_session_token: " aws_session_token < /dev/tty

        if [[ -z "$aws_key_id" || -z "$aws_secret_key" || -z "$aws_session_token" ]]; then
            error "All three credential fields are required."
            exit 1
        fi

        echo ""
        info "Configuring AWS profile and verifying credentials..."

        # Configure dedicated profile
        aws configure set aws_access_key_id "$aws_key_id" --profile "$AWS_PROFILE_NAME"
        aws configure set aws_secret_access_key "$aws_secret_key" --profile "$AWS_PROFILE_NAME"
        aws configure set aws_session_token "$aws_session_token" --profile "$AWS_PROFILE_NAME"
        aws configure set region "$REGION" --profile "$AWS_PROFILE_NAME"

        # Verify credentials work
        if aws sts get-caller-identity --profile "$AWS_PROFILE_NAME" &> /dev/null; then
            ok "AWS credentials configured (profile: $AWS_PROFILE_NAME). Account: $(aws sts get-caller-identity --profile "$AWS_PROFILE_NAME" --query Account --output text)"
            return 0
        fi

        # Credentials failed — ask to retry
        echo ""
        error "Credentials are invalid or expired."
        echo ""
        echo "  Common causes:"
        echo "    • Credentials were copied incorrectly (missing characters)"
        echo "    • AWS Academy Lab session has expired (restart the lab)"
        echo "    • Wrong credentials were pasted"
        echo ""
        read -rp "  Do you want to enter new credentials? [Y/n]: " retry < /dev/tty
        if [[ "$retry" =~ ^[Nn]$ ]]; then
            error "Cannot proceed without valid AWS credentials."
            exit 1
        fi
        echo ""
    done
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
        read -rp "  Do you want to replace it? [y/N]: " replace_key < /dev/tty
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

    while IFS= read -r line < /dev/tty; do
        # Stop on empty line after we have content
        if [[ -z "$line" && -n "$key_content" ]]; then
            break
        fi
        key_content+="$line"$'\n'
    done

    echo ""
    info "Processing SSH key..."

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

# Check if a Kiro-LAB instance already exists (running or stopped)
check_existing_instance() {
    local existing_id
    existing_id=$(aws ec2 describe-instances \
        --profile "$AWS_PROFILE_NAME" \
        --filters "Name=tag:Name,Values=$INSTANCE_NAME" \
                  "Name=instance-state-name,Values=running,stopped,pending" \
        --query 'Reservations[].Instances[0].InstanceId' \
        --region "$REGION" \
        --output text 2>/dev/null || echo "")

    if [[ -n "$existing_id" && "$existing_id" != "None" ]]; then
        echo ""
        warn "An existing Kiro-LAB instance was found: $existing_id"
        echo ""
        echo -e "  ${YELLOW}Deploying again will TERMINATE the existing instance and create a new one.${NC}"
        echo ""
        read -rp "  Do you want to continue? (The old instance will be deleted) [y/N]: " confirm < /dev/tty
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            info "Deployment cancelled."
            exit 0
        fi

        echo ""
        # Terminate existing instance
        info "Terminating existing instance: $existing_id (this may take a moment)..."
        aws ec2 terminate-instances \
            --profile "$AWS_PROFILE_NAME" \
            --instance-ids "$existing_id" \
            --region "$REGION" > /dev/null
        aws ec2 wait instance-terminated \
            --profile "$AWS_PROFILE_NAME" \
            --instance-ids "$existing_id" \
            --region "$REGION" 2>/dev/null || true
        ok "Existing instance terminated."
    fi
}

get_ubuntu_ami() {
    info "Finding latest Ubuntu 26.04 AMI in $REGION..."

    # Try SSM parameter for Ubuntu 26.04
    AMI_ID=$(aws ssm get-parameters \
        --profile "$AWS_PROFILE_NAME" \
        --names /aws/service/canonical/ubuntu/server/26.04/stable/current/amd64/hvm/ebs-gp3/ami-id \
        --region "$REGION" \
        --query 'Parameters[0].Value' \
        --output text 2>/dev/null || echo "")

    if [[ -z "$AMI_ID" || "$AMI_ID" == "None" ]]; then
        # Fallback: search for Ubuntu 26.04 by name pattern
        AMI_ID=$(aws ec2 describe-images \
            --profile "$AWS_PROFILE_NAME" \
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
            --profile "$AWS_PROFILE_NAME" \
            --names /aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id \
            --region "$REGION" \
            --query 'Parameters[0].Value' \
            --output text 2>/dev/null || echo "")

        if [[ -z "$AMI_ID" || "$AMI_ID" == "None" ]]; then
            AMI_ID=$(aws ec2 describe-images \
                --profile "$AWS_PROFILE_NAME" \
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
        --profile "$AWS_PROFILE_NAME" \
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
        --profile "$AWS_PROFILE_NAME" \
        --group-name "$sg_name" \
        --description "Security group for Kiro-LAB SSH development instance" \
        --region "$REGION" \
        --output text --query 'GroupId')

    # Allow SSH from anywhere (for lab purposes)
    aws ec2 authorize-security-group-ingress \
        --profile "$AWS_PROFILE_NAME" \
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
#!/bin/bash -x
export HOME="${HOME:-/root}"
exec > /var/log/userdata-kiro-lab.log 2>&1
apt update -y && apt upgrade -y
apt install -y build-essential curl wget unzip git python3 python3-pip python3-venv
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt install -y nodejs
npm install -g npm@latest || true
su - ubuntu -c "export BUN_INSTALL=/home/ubuntu/.bun && curl -fsSL https://bun.sh/install | bash" || true
ln -sf /home/ubuntu/.bun/bin/bun /usr/local/bin/bun 2>/dev/null || true
ln -sf /home/ubuntu/.bun/bin/bun /usr/local/bin/bunx 2>/dev/null || true
curl -LsSf https://astral.sh/uv/install.sh | sh || true
ln -sf /root/.local/bin/uv /usr/local/bin/uv 2>/dev/null || true
ln -sf /root/.local/bin/uvx /usr/local/bin/uvx 2>/dev/null || true
su - ubuntu -c "curl -LsSf https://astral.sh/uv/install.sh | sh" || true
su - ubuntu -c "/home/ubuntu/.local/bin/uv tool install graphifyy" || true
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
unzip -q /tmp/awscliv2.zip -d /tmp && /tmp/aws/install && rm -rf /tmp/aws /tmp/awscliv2.zip
su - ubuntu -c "git clone https://github.com/chaisit/aws-kiro-workshop.git /home/ubuntu/workshop"
su - ubuntu -c "mkdir -p /home/ubuntu/.kiro/settings"
cat > /home/ubuntu/.kiro/settings/mcp.json << 'EOF'
{"mcpServers":{"aws-docs":{"command":"/home/ubuntu/.local/bin/uvx","args":["awslabs.aws-documentation-mcp-server@latest"],"env":{"FASTMCP_LOG_LEVEL":"ERROR"},"disabled":false},"awsiac":{"command":"/home/ubuntu/.local/bin/uvx","args":["awslabs.aws-iac-mcp-server@latest"]},"awsknowledge":{"url":"https://knowledge-mcp.global.api.aws"},"awspricing":{"command":"/home/ubuntu/.local/bin/uvx","args":["awslabs.aws-pricing-mcp-server@latest"],"env":{"FASTMCP_LOG_LEVEL":"ERROR"}}}}
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
        --profile "$AWS_PROFILE_NAME" \
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
    aws ec2 wait instance-running \
        --profile "$AWS_PROFILE_NAME" \
        --instance-ids "$INSTANCE_ID" \
        --region "$REGION"
    ok "Instance is running!"
}

get_instance_dns() {
    info "Getting instance public DNS name..."

    # Wait a moment for DNS to propagate
    sleep 5

    PUBLIC_DNS=$(aws ec2 describe-instances \
        --profile "$AWS_PROFILE_NAME" \
        --instance-ids "$INSTANCE_ID" \
        --query 'Reservations[0].Instances[0].PublicDnsName' \
        --region "$REGION" \
        --output text)

    PUBLIC_IP=$(aws ec2 describe-instances \
        --profile "$AWS_PROFILE_NAME" \
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
    echo "  AWS Profile:   $AWS_PROFILE_NAME"
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
    echo -e "  ${BLUE}To clean up all resources later:${NC}"
    echo "    bash deploy-kiro-lab.sh cleanup"
    echo ""
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
}

# ─── Cleanup ─────────────────────────────────────────────────────────────────

do_cleanup() {
    echo ""
    echo -e "${YELLOW}╔══════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║   Kiro-LAB Cleanup                       ║${NC}"
    echo -e "${YELLOW}╚══════════════════════════════════════════╝${NC}"
    echo ""

    # Check prerequisites
    if ! command -v aws &> /dev/null; then
        error "AWS CLI not found. Cannot perform cleanup."
        exit 1
    fi

    # Check profile exists and is valid
    if ! aws sts get-caller-identity --profile "$AWS_PROFILE_NAME" &> /dev/null; then
        error "AWS profile '$AWS_PROFILE_NAME' is not configured or credentials are expired."
        echo "  Please run the deploy script first to configure credentials,"
        echo "  or manually configure the profile:"
        echo "    aws configure --profile $AWS_PROFILE_NAME"
        exit 1
    fi

    info "This will remove the following resources:"
    echo ""

    # Find instances
    local instance_ids
    instance_ids=$(aws ec2 describe-instances \
        --profile "$AWS_PROFILE_NAME" \
        --filters "Name=tag:Name,Values=$INSTANCE_NAME" \
                  "Name=instance-state-name,Values=running,stopped,pending" \
        --query 'Reservations[].Instances[].InstanceId' \
        --region "$REGION" \
        --output text 2>/dev/null || echo "")

    if [[ -n "$instance_ids" && "$instance_ids" != "None" ]]; then
        echo "  • EC2 Instance(s): $instance_ids"
    else
        echo "  • EC2 Instance(s): (none found)"
    fi

    # Find security group
    local sg_id
    sg_id=$(aws ec2 describe-security-groups \
        --profile "$AWS_PROFILE_NAME" \
        --filters "Name=group-name,Values=kiro-lab-sg" \
        --query 'SecurityGroups[0].GroupId' \
        --region "$REGION" \
        --output text 2>/dev/null || echo "None")

    if [[ "$sg_id" != "None" && -n "$sg_id" ]]; then
        echo "  • Security Group: $sg_id (kiro-lab-sg)"
    else
        echo "  • Security Group: (none found)"
    fi

    echo "  • SSH Config: 'kiro-lab' entry in ~/.ssh/config"
    echo "  • AWS Profile: '$AWS_PROFILE_NAME' from ~/.aws/credentials and ~/.aws/config"
    echo ""

    read -rp "  Are you sure you want to delete all these resources? [y/N]: " confirm < /dev/tty
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        info "Cleanup cancelled."
        exit 0
    fi

    echo ""
    info "Starting cleanup process..."
    echo ""

    # Terminate instances
    if [[ -n "$instance_ids" && "$instance_ids" != "None" ]]; then
        info "Terminating EC2 instance(s): $instance_ids ..."
        aws ec2 terminate-instances \
            --profile "$AWS_PROFILE_NAME" \
            --instance-ids $instance_ids \
            --region "$REGION" > /dev/null
        info "Waiting for instance(s) to terminate..."
        aws ec2 wait instance-terminated \
            --profile "$AWS_PROFILE_NAME" \
            --instance-ids $instance_ids \
            --region "$REGION" 2>/dev/null || true
        ok "Instance(s) terminated."
    fi

    # Delete security group (may need retry as ENIs detach)
    if [[ "$sg_id" != "None" && -n "$sg_id" ]]; then
        info "Deleting security group: $sg_id ..."
        local retries=0
        while [[ $retries -lt 5 ]]; do
            if aws ec2 delete-security-group \
                --profile "$AWS_PROFILE_NAME" \
                --group-id "$sg_id" \
                --region "$REGION" 2>/dev/null; then
                ok "Security group deleted."
                break
            fi
            retries=$((retries + 1))
            if [[ $retries -lt 5 ]]; then
                warn "Security group still in use, retrying in 10s... ($retries/5)"
                sleep 10
            else
                warn "Could not delete security group. It may still be attached to a network interface."
                warn "You can delete it manually: aws ec2 delete-security-group --group-id $sg_id --region $REGION --profile $AWS_PROFILE_NAME"
            fi
        done
    fi

    # Remove SSH config entry
    local ssh_config="$HOME/.ssh/config"
    if [[ -f "$ssh_config" ]]; then
        if grep -q '# >>> Kiro-LAB >>>' "$ssh_config"; then
            sed -i.bak '/^# >>> Kiro-LAB >>>/,/^# <<< Kiro-LAB <<</d' "$ssh_config"
            ok "SSH config entry removed."
        fi
    fi

    # Remove AWS profile
    info "Removing AWS profile '$AWS_PROFILE_NAME'..."
    # Remove from credentials file
    local creds_file="$HOME/.aws/credentials"
    if [[ -f "$creds_file" ]] && grep -q "\[$AWS_PROFILE_NAME\]" "$creds_file"; then
        sed -i.bak "/^\[$AWS_PROFILE_NAME\]/,/^\[/{ /^\[${AWS_PROFILE_NAME}\]/d; /^\[/!d; }" "$creds_file"
        # Clean up empty lines
        sed -i.bak '/^$/N;/^\n$/d' "$creds_file" && rm -f "${creds_file}.bak"
    fi
    # Remove from config file
    local config_file="$HOME/.aws/config"
    if [[ -f "$config_file" ]] && grep -q "\[profile $AWS_PROFILE_NAME\]" "$config_file"; then
        sed -i.bak "/^\[profile $AWS_PROFILE_NAME\]/,/^\[/{ /^\[profile ${AWS_PROFILE_NAME}\]/d; /^\[/!d; }" "$config_file"
        sed -i.bak '/^$/N;/^\n$/d' "$config_file" && rm -f "${config_file}.bak"
    fi
    ok "AWS profile removed."

    echo ""
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Kiro-LAB Cleanup Complete!${NC}"
    echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "  All Kiro-LAB resources have been removed."
    echo ""
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
    check_existing_instance
    collect_ssh_key
    get_ubuntu_ami
    create_security_group
    get_userdata
    launch_instance
    get_instance_dns
    configure_ssh
    print_summary
}

# ─── Entry Point ─────────────────────────────────────────────────────────────

case "${ACTION:-}" in
    cleanup|clean|destroy|teardown)
        check_prerequisites
        do_cleanup
        ;;
    *)
        main
        ;;
esac
