# =============================================================================
# deploy-kiro-lab.ps1
# Deploys an EC2 instance (Kiro-LAB) for remote SSH development with Kiro IDE
#
# Usage:
#   irm https://raw.githubusercontent.com/YOUR_REPO/labs/deploy-kiro-lab.ps1 | iex
#   -- or --
#   .\deploy-kiro-lab.ps1
#
# Prerequisites:
#   - AWS CLI (will be installed automatically if missing)
#   - AWS Academy Lab credentials (script will prompt)
#   - vockey.pem SSH key from AWS Academy Lab (script will prompt)
# =============================================================================

#Requires -Version 5.1
$ErrorActionPreference = "Stop"

# ─── Configuration ───────────────────────────────────────────────────────────
$INSTANCE_NAME = "Kiro-LAB"
$KEY_NAME = "vockey"
$INSTANCE_TYPE = "t3.medium"
$VOLUME_SIZE = 30
$REGION = if ($env:AWS_DEFAULT_REGION) { $env:AWS_DEFAULT_REGION } else { "us-east-1" }
$SSH_CONFIG_HOST = "kiro-lab"
$USERDATA_URL = "https://raw.githubusercontent.com/YOUR_REPO/labs/userdata-kiro-lab.sh"

# ─── Functions ───────────────────────────────────────────────────────────────

function Write-Info  { param($Msg) Write-Host "[INFO] $Msg" -ForegroundColor Cyan }
function Write-Ok    { param($Msg) Write-Host "[OK]   $Msg" -ForegroundColor Green }
function Write-Warn  { param($Msg) Write-Host "[WARN] $Msg" -ForegroundColor Yellow }
function Write-Err   { param($Msg) Write-Host "[ERROR] $Msg" -ForegroundColor Red }

function Collect-AWSCredentials {
    Write-Host ""
    Write-Info "--- AWS Lab Credentials Setup ---"
    Write-Host ""
    Write-Host "  Paste your AWS credentials from the AWS Academy Lab page."
    Write-Host "  (Click 'AWS Details' -> 'Show' next to AWS CLI credentials)"
    Write-Host ""

    # Check if credentials are already valid
    $null = aws sts get-caller-identity --output json 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "AWS credentials already configured and valid."
        $reconfigure = Read-Host "  Do you want to reconfigure? [y/N]"
        if ($reconfigure -notmatch '^[Yy]$') {
            return
        }
    }

    # Prompt for credentials
    $awsKeyId = Read-Host "  aws_access_key_id"
    $awsSecretKey = Read-Host "  aws_secret_access_key"
    $awsSessionToken = Read-Host "  aws_session_token"

    if (-not $awsKeyId -or -not $awsSecretKey -or -not $awsSessionToken) {
        Write-Err "All three credential fields are required."
        exit 1
    }

    # Export as environment variables for this session
    $env:AWS_ACCESS_KEY_ID = $awsKeyId
    $env:AWS_SECRET_ACCESS_KEY = $awsSecretKey
    $env:AWS_SESSION_TOKEN = $awsSessionToken
    $env:AWS_DEFAULT_REGION = $REGION

    # Verify credentials work
    $null = aws sts get-caller-identity --output json 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Credentials are invalid or expired. Please check and try again."
        exit 1
    }

    $account = aws sts get-caller-identity --query "Account" --output text
    Write-Ok "AWS credentials configured. Account: $account"
}

function Collect-SSHKey {
    Write-Host ""
    Write-Info "--- SSH Private Key Setup ---"
    Write-Host ""

    $sshDir = Join-Path $env:USERPROFILE ".ssh"
    $keyFile = Join-Path $sshDir "vockey.pem"

    # Check if key already exists
    if (Test-Path $keyFile) {
        Write-Ok "SSH key already exists: $keyFile"
        $replaceKey = Read-Host "  Do you want to replace it? [y/N]"
        if ($replaceKey -notmatch '^[Yy]$') {
            $script:SSH_KEY_PATH = $keyFile
            return
        }
    }

    # Search common locations first
    $searchPaths = @(
        ".\vockey.pem",
        ".\aws-credentials\vockey.pem",
        "$env:USERPROFILE\Downloads\vockey.pem",
        "$env:USERPROFILE\labsuser.pem"
    )

    foreach ($path in $searchPaths) {
        if (Test-Path $path) {
            $script:SSH_KEY_PATH = (Resolve-Path $path).Path
            Write-Ok "Found existing SSH key: $script:SSH_KEY_PATH"
            return
        }
    }

    Write-Host "  Paste your SSH private key (vockey.pem) from AWS Academy Lab."
    Write-Host "  (Click 'AWS Details' -> 'Show' next to SSH Key)"
    Write-Host ""
    Write-Host "  Paste the key below (including BEGIN/END lines),"
    Write-Host "  then type 'END' on a new line and press Enter:"
    Write-Host ""

    # Read multi-line key input
    if (-not (Test-Path $sshDir)) {
        New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
    }

    $keyLines = @()
    while ($true) {
        $line = Read-Host
        if ($line -eq "END" -and $keyLines.Count -gt 0) {
            break
        }
        $keyLines += $line
    }

    $keyContent = ($keyLines -join "`n") + "`n"

    # Validate it looks like a private key
    if ($keyContent -notmatch "BEGIN.*PRIVATE KEY") {
        Write-Err "Input does not appear to be a valid private key."
        exit 1
    }

    # Write key file
    Set-Content -Path $keyFile -Value $keyContent -Encoding ASCII -NoNewline

    # Set restrictive permissions (Windows equivalent of chmod 400)
    $acl = Get-Acl $keyFile
    $acl.SetAccessRuleProtection($true, $false)
    $acl.Access | ForEach-Object { $acl.RemoveAccessRule($_) } | Out-Null
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($currentUser, "Read", "Allow")
    $acl.AddAccessRule($rule)
    Set-Acl -Path $keyFile -AclObject $acl

    $script:SSH_KEY_PATH = $keyFile
    Write-Ok "SSH key saved: $script:SSH_KEY_PATH"
}

function Install-AWSCLI {
    Write-Info "AWS CLI not found. Installing..."

    $msiUrl = "https://awscli.amazonaws.com/AWSCLIV2.msi"
    $msiPath = Join-Path $env:TEMP "AWSCLIV2.msi"

    Write-Info "Downloading AWS CLI installer for Windows..."
    Invoke-WebRequest -Uri $msiUrl -OutFile $msiPath -UseBasicParsing

    Write-Info "Installing AWS CLI (this may take a minute)..."
    Start-Process msiexec.exe -ArgumentList "/i", $msiPath, "/quiet", "/norestart" -Wait -NoNewWindow

    Remove-Item $msiPath -Force -ErrorAction SilentlyContinue

    # Refresh PATH
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")

    # Verify
    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        Write-Err "AWS CLI installation failed. Please install manually:"
        Write-Host "  https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
        exit 1
    }

    Write-Ok "AWS CLI installed: $(aws --version)"
}

function Test-Prerequisites {
    Write-Info "Checking prerequisites..."

    # Install AWS CLI if not present
    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        Install-AWSCLI
    }
    else {
        Write-Ok "AWS CLI found: $(aws --version 2>&1 | Select-Object -First 1)"
    }
}

function Get-UbuntuAMI {
    Write-Info "Finding latest Ubuntu 26.04 AMI in $REGION..."

    # Try SSM parameter for Ubuntu 26.04
    $script:AMI_ID = aws ssm get-parameters `
        --names "/aws/service/canonical/ubuntu/server/26.04/stable/current/amd64/hvm/ebs-gp3/ami-id" `
        --region $REGION `
        --query "Parameters[0].Value" `
        --output text 2>$null

    if (-not $script:AMI_ID -or $script:AMI_ID -eq "None") {
        # Fallback: search by name pattern
        $script:AMI_ID = aws ec2 describe-images `
            --owners 099720109477 `
            --filters "Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-*-26.04-amd64-server-*" `
            --query "Images | sort_by(@, &CreationDate) | [-1].ImageId" `
            --region $REGION `
            --output text 2>$null
    }

    if (-not $script:AMI_ID -or $script:AMI_ID -eq "None") {
        # Fallback: Ubuntu 24.04 if 26.04 not available yet
        Write-Warn "Ubuntu 26.04 not found, falling back to 24.04..."
        $script:AMI_ID = aws ssm get-parameters `
            --names "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id" `
            --region $REGION `
            --query "Parameters[0].Value" `
            --output text 2>$null

        if (-not $script:AMI_ID -or $script:AMI_ID -eq "None") {
            $script:AMI_ID = aws ec2 describe-images `
                --owners 099720109477 `
                --filters "Name=name,Values=ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*" `
                --query "Images | sort_by(@, &CreationDate) | [-1].ImageId" `
                --region $REGION `
                --output text 2>$null
        }
    }

    if (-not $script:AMI_ID -or $script:AMI_ID -eq "None") {
        Write-Err "Could not find Ubuntu AMI in region $REGION"
        exit 1
    }

    Write-Ok "AMI: $script:AMI_ID"
}

function New-SecurityGroup {
    Write-Info "Setting up security group..."

    $sgName = "kiro-lab-sg"

    # Check if already exists
    $script:SG_ID = aws ec2 describe-security-groups `
        --filters "Name=group-name,Values=$sgName" `
        --query "SecurityGroups[0].GroupId" `
        --region $REGION `
        --output text 2>$null

    if ($script:SG_ID -and $script:SG_ID -ne "None") {
        Write-Ok "Security group already exists: $script:SG_ID"
        return
    }

    # Create security group
    $script:SG_ID = aws ec2 create-security-group `
        --group-name $sgName `
        --description "Security group for Kiro-LAB SSH development instance" `
        --region $REGION `
        --output text --query "GroupId"

    # Allow SSH only
    aws ec2 authorize-security-group-ingress `
        --group-id $script:SG_ID `
        --protocol tcp --port 22 --cidr "0.0.0.0/0" `
        --region $REGION | Out-Null

    Write-Ok "Created security group: $script:SG_ID (SSH inbound only)"
}

function Get-Userdata {
    Write-Info "Preparing userdata script..."

    $localPath = Join-Path $PSScriptRoot "userdata-kiro-lab.sh"
    $tempPath = Join-Path $env:TEMP "kiro-lab-userdata.sh"

    if (Test-Path $localPath) {
        $script:USERDATA_PATH = $localPath
        Write-Info "Using local userdata script"
    }
    else {
        # Try download
        try {
            Invoke-WebRequest -Uri $USERDATA_URL -OutFile $tempPath -UseBasicParsing
            $script:USERDATA_PATH = $tempPath
            Write-Info "Downloaded userdata from remote"
        }
        catch {
            # Write embedded userdata
            Write-Warn "Could not fetch userdata, using embedded version"
            $embeddedUserdata = @'
#!/bin/bash -xe
exec > /var/log/userdata-kiro-lab.log 2>&1
apt update -y && apt upgrade -y
apt install -y build-essential curl wget unzip git python3 python3-pip python3-venv
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs
npm install -g npm@latest || true
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
su - ubuntu -c "git clone https://git.rmutsv.app/kai/aws-academy-kiro-workshop.git /home/ubuntu/workshop"
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
'@
            Set-Content -Path $tempPath -Value $embeddedUserdata -Encoding UTF8 -NoNewline
            $script:USERDATA_PATH = $tempPath
        }
    }
}

function Start-Instance {
    Write-Info "Launching EC2 instance ($INSTANCE_TYPE)..."

    $script:INSTANCE_ID = aws ec2 run-instances `
        --image-id $script:AMI_ID `
        --instance-type $INSTANCE_TYPE `
        --key-name $KEY_NAME `
        --security-group-ids $script:SG_ID `
        --iam-instance-profile "Name=LabInstanceProfile" `
        --block-device-mappings "DeviceName=/dev/sda1,Ebs={VolumeSize=$VOLUME_SIZE,VolumeType=gp3,Encrypted=true}" `
        --user-data "file://$($script:USERDATA_PATH)" `
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" `
        --region $REGION `
        --query "Instances[0].InstanceId" `
        --output text

    Write-Ok "Instance launched: $script:INSTANCE_ID"

    Write-Info "Waiting for instance to enter running state..."
    aws ec2 wait instance-running --instance-ids $script:INSTANCE_ID --region $REGION
    Write-Ok "Instance is running!"
}

function Get-InstanceDNS {
    Write-Info "Getting instance public DNS name..."

    Start-Sleep -Seconds 5

    $script:PUBLIC_DNS = aws ec2 describe-instances `
        --instance-ids $script:INSTANCE_ID `
        --query "Reservations[0].Instances[0].PublicDnsName" `
        --region $REGION `
        --output text

    $script:PUBLIC_IP = aws ec2 describe-instances `
        --instance-ids $script:INSTANCE_ID `
        --query "Reservations[0].Instances[0].PublicIpAddress" `
        --region $REGION `
        --output text

    if (-not $script:PUBLIC_DNS -or $script:PUBLIC_DNS -eq "None") {
        Write-Warn "No public DNS assigned. Using public IP: $script:PUBLIC_IP"
        $script:PUBLIC_DNS = $script:PUBLIC_IP
    }

    Write-Ok "Public DNS: $script:PUBLIC_DNS"
    Write-Ok "Public IP:  $script:PUBLIC_IP"
}

function Set-SSHConfig {
    Write-Info "Configuring SSH..."

    $sshDir = Join-Path $env:USERPROFILE ".ssh"
    $sshConfig = Join-Path $sshDir "config"

    # Ensure .ssh directory exists
    if (-not (Test-Path $sshDir)) {
        New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
    }

    # Convert key path to use forward slashes for SSH compatibility
    $sshKeyPath = $script:SSH_KEY_PATH -replace '\\', '/'

    # Build new SSH config entry (quote IdentityFile path to handle spaces)
    $newEntry = @"

# >>> Kiro-LAB >>>
Host $SSH_CONFIG_HOST
    HostName $($script:PUBLIC_DNS)
    User ubuntu
    IdentityFile "$sshKeyPath"
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel ERROR
    ServerAliveInterval 60
    ServerAliveCountMax 10
# <<< Kiro-LAB <<<
"@

    # Remove old entry if exists
    if (Test-Path $sshConfig) {
        $content = Get-Content $sshConfig -Raw
        $content = $content -replace '(?s)# >>> Kiro-LAB >>>.*?# <<< Kiro-LAB <<<\r?\n?', ''
        Set-Content -Path $sshConfig -Value $content.TrimEnd() -Encoding UTF8 -NoNewline
    }

    # Append new entry
    Add-Content -Path $sshConfig -Value $newEntry -Encoding UTF8

    Write-Ok "SSH config updated: $sshConfig"
    Write-Host ""
    Write-Host "  You can now connect with:  ssh $SSH_CONFIG_HOST"
}

function Show-Summary {
    Write-Host ""
    Write-Host "==============================================================" -ForegroundColor Green
    Write-Host "  Kiro-LAB Instance Deployed Successfully!" -ForegroundColor Green
    Write-Host "==============================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Instance ID:   $($script:INSTANCE_ID)"
    Write-Host "  Public DNS:    $($script:PUBLIC_DNS)"
    Write-Host "  Public IP:     $($script:PUBLIC_IP)"
    Write-Host "  Instance Type: $INSTANCE_TYPE"
    Write-Host "  Region:        $REGION"
    Write-Host ""
    Write-Host "  SSH Command:   " -NoNewline; Write-Host "ssh $SSH_CONFIG_HOST" -ForegroundColor Cyan
    Write-Host "  SSH Config:    " -NoNewline; Write-Host "Host '$SSH_CONFIG_HOST' added to ~/.ssh/config" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  NOTE: The instance is still running userdata setup (~3-5 min)." -ForegroundColor Yellow
    Write-Host "  Check progress:  ssh $SSH_CONFIG_HOST 'tail -f /var/log/userdata-kiro-lab.log'" -ForegroundColor Yellow
    Write-Host "  Check ready:     ssh $SSH_CONFIG_HOST 'ls ~/.kiro-lab-ready 2>/dev/null && echo READY'" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  --- Kiro Remote SSH Setup ---"
    Write-Host "  1. Open Kiro IDE"
    Write-Host "  2. Install 'Remote - SSH' extension (if not already)"
    Write-Host "  3. Ctrl+Shift+P -> 'Remote-SSH: Connect to Host...'"
    Write-Host "  4. Select '$SSH_CONFIG_HOST'"
    Write-Host "  5. Open folder: /home/ubuntu/workshop"
    Write-Host ""
    Write-Host "==============================================================" -ForegroundColor Green
}

# ─── Main ────────────────────────────────────────────────────────────────────

function Main {
    Write-Host ""
    Write-Host "+===========================================+" -ForegroundColor Cyan
    Write-Host "|   Kiro-LAB EC2 Instance Deployment        |" -ForegroundColor Cyan
    Write-Host "+===========================================+" -ForegroundColor Cyan
    Write-Host ""

    Test-Prerequisites
    Collect-AWSCredentials
    Collect-SSHKey
    Get-UbuntuAMI
    New-SecurityGroup
    Get-Userdata
    Start-Instance
    Get-InstanceDNS
    Set-SSHConfig
    Show-Summary
}

Main
