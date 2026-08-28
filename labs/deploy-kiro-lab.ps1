# =============================================================================
# deploy-kiro-lab.ps1
# Deploys an EC2 instance (Kiro-LAB) for remote SSH development with Kiro IDE
#
# Usage:
#   irm https://github.com/chaisit/aws-kiro-workshop/raw/refs/heads/main/labs/deploy-kiro-lab.ps1 | iex
#   -- or --
#   .\deploy-kiro-lab.ps1
#   .\deploy-kiro-lab.ps1 -Region us-west-2
#   .\deploy-kiro-lab.ps1 -Action cleanup -Region us-west-2
#
# Prerequisites:
#   - AWS CLI (will be installed automatically if missing)
#   - AWS Academy Lab credentials (script will prompt)
#   - vockey.pem SSH key from AWS Academy Lab (script will prompt)
# =============================================================================

#Requires -Version 5.1
param(
    [ValidateSet("deploy", "cleanup", "clean", "destroy", "teardown")]
    [string]$Action = "deploy",

    [string]$Region = ""
)

# NOTE: We use "Continue" instead of "Stop" because native commands (aws cli)
# write diagnostic messages to stderr which PowerShell treats as ErrorRecords.
# With "Stop", any stderr output becomes a terminating error even when redirected.
# The script handles errors explicitly via $LASTEXITCODE checks after aws calls.
$ErrorActionPreference = "Continue"

# ─── Configuration ───────────────────────────────────────────────────────────
$INSTANCE_NAME = "Kiro-LAB"
$KEY_NAME = "vockey"
$INSTANCE_TYPE = "t3.medium"
$VOLUME_SIZE = 30
$REGION = if ($Region) { $Region } elseif ($env:AWS_DEFAULT_REGION) { $env:AWS_DEFAULT_REGION } else { "us-east-1" }
$SSH_CONFIG_HOST = "kiro-lab"
$USERDATA_URL = "https://github.com/chaisit/aws-kiro-workshop/raw/refs/heads/main/labs/userdata-kiro-lab.sh"
$AWS_PROFILE_NAME = "kiro-lab-deploy"

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

    # Check if profile credentials are already valid
    $null = aws sts get-caller-identity --profile $AWS_PROFILE_NAME --output json 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "AWS credentials already configured and valid (profile: $AWS_PROFILE_NAME)."
        $reconfigure = Read-Host "  Do you want to reconfigure? [y/N]"
        if ($reconfigure -notmatch '^[Yy]$') {
            return
        }
    }

    # Credential input loop with retry on failure
    while ($true) {
        # Prompt for credentials
        $awsKeyId = Read-Host "  aws_access_key_id"
        $awsSecretKey = Read-Host "  aws_secret_access_key"
        $awsSessionToken = Read-Host "  aws_session_token"

        if (-not $awsKeyId -or -not $awsSecretKey -or -not $awsSessionToken) {
            Write-Err "All three credential fields are required."
            exit 1
        }

        Write-Host ""
        Write-Info "Configuring AWS profile and verifying credentials..."

        # Configure dedicated profile
        aws configure set aws_access_key_id $awsKeyId --profile $AWS_PROFILE_NAME
        aws configure set aws_secret_access_key $awsSecretKey --profile $AWS_PROFILE_NAME
        aws configure set aws_session_token $awsSessionToken --profile $AWS_PROFILE_NAME
        aws configure set region $REGION --profile $AWS_PROFILE_NAME

        # Verify credentials work
        $null = aws sts get-caller-identity --profile $AWS_PROFILE_NAME --output json 2>$null
        if ($LASTEXITCODE -eq 0) {
            $account = aws sts get-caller-identity --profile $AWS_PROFILE_NAME --query "Account" --output text
            Write-Ok "AWS credentials configured (profile: $AWS_PROFILE_NAME). Account: $account"
            return
        }

        # Credentials failed — ask to retry
        Write-Host ""
        Write-Err "Credentials are invalid or expired."
        Write-Host ""
        Write-Host "  Common causes:"
        Write-Host "    - Credentials were copied incorrectly (missing characters)"
        Write-Host "    - AWS Academy Lab session has expired (restart the lab)"
        Write-Host "    - Wrong credentials were pasted"
        Write-Host ""
        $retry = Read-Host "  Do you want to enter new credentials? [Y/n]"
        if ($retry -match '^[Nn]$') {
            Write-Err "Cannot proceed without valid AWS credentials."
            exit 1
        }
        Write-Host ""
    }
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

    Write-Host ""
    Write-Info "Processing SSH key..."

    # Validate it looks like a private key
    if ($keyContent -notmatch "BEGIN.*PRIVATE KEY") {
        Write-Err "Input does not appear to be a valid private key."
        exit 1
    }

    # Remove existing key file if present (it may have restrictive ACL from previous run)
    if (Test-Path $keyFile) {
        # Use icacls to grant full control — does not require SeSecurityPrivilege
        icacls $keyFile /grant "${env:USERNAME}:(F)" /C /Q 2>$null | Out-Null
        Remove-Item -Path $keyFile -Force -ErrorAction SilentlyContinue

        # If Remove-Item still failed, try .NET File.Delete as last resort
        if (Test-Path $keyFile) {
            try { [System.IO.File]::SetAttributes($keyFile, 'Normal') } catch {}
            try { [System.IO.File]::Delete($keyFile) } catch {}
        }

        if (Test-Path $keyFile) {
            Write-Err "Cannot remove existing key file: $keyFile"
            Write-Host "  Try running PowerShell as Administrator, or delete the file manually."
            exit 1
        }
    }

    # Write key file
    Set-Content -Path $keyFile -Value $keyContent -Encoding ASCII -NoNewline

    # Set restrictive permissions (Windows equivalent of chmod 400)
    # Use icacls as primary method — it works without SeSecurityPrivilege
    icacls $keyFile /inheritance:r /C /Q 2>$null | Out-Null
    icacls $keyFile /grant:r "${env:USERNAME}:(R)" /C /Q 2>$null | Out-Null

    $script:SSH_KEY_PATH = $keyFile
    Write-Ok "SSH key saved: $script:SSH_KEY_PATH"
}

function Refresh-PathEnvironment {
    # Reload PATH from registry so newly installed programs are visible in this session
    $machinePath = [System.Environment]::GetEnvironmentVariable("PATH", "Machine")
    $userPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
    $env:PATH = "$machinePath;$userPath"
}

function Install-AWSCLI {
    Write-Info "AWS CLI not found. Installing..."

    # Try winget first (does not require elevated permissions)
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Info "Installing AWS CLI via winget..."
        winget install Amazon.AWSCLI --accept-source-agreements --accept-package-agreements --silent
        if ($LASTEXITCODE -eq 0) {
            Write-Info "Refreshing PATH..."
            Refresh-PathEnvironment
            if (Get-Command aws -ErrorAction SilentlyContinue) {
                Write-Ok "AWS CLI installed: $(aws --version)"
                return
            }
            Write-Warn "winget install succeeded but 'aws' not yet in PATH. Trying known install path..."
            # Add default AWS CLI install location manually
            $awsCliPath = "C:\Program Files\Amazon\AWSCLIV2"
            if (Test-Path $awsCliPath) {
                $env:PATH = "$awsCliPath;$env:PATH"
            }
            if (Get-Command aws -ErrorAction SilentlyContinue) {
                Write-Ok "AWS CLI installed: $(aws --version)"
                return
            }
        }
        Write-Warn "winget installation did not succeed, trying MSI installer..."
    }

    # Fallback: MSI installer (may require elevated permissions)
    $msiUrl = "https://awscli.amazonaws.com/AWSCLIV2.msi"
    $msiPath = Join-Path $env:TEMP "AWSCLIV2.msi"

    Write-Info "Downloading AWS CLI installer for Windows..."
    try {
        Invoke-WebRequest -Uri $msiUrl -OutFile $msiPath -UseBasicParsing -ErrorAction Stop
    }
    catch {
        Write-Err "Failed to download AWS CLI installer: $_"
        Write-Host "  Please install manually: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
        exit 1
    }

    Write-Info "Installing AWS CLI via MSI (this may take a minute)..."
    Start-Process msiexec.exe -ArgumentList "/i", $msiPath, "/quiet", "/norestart" -Wait -NoNewWindow

    Remove-Item $msiPath -Force -ErrorAction SilentlyContinue

    # Refresh PATH
    Refresh-PathEnvironment

    # Also try adding the default install location directly
    $awsCliPath = "C:\Program Files\Amazon\AWSCLIV2"
    if ((Test-Path $awsCliPath) -and ($env:PATH -notlike "*$awsCliPath*")) {
        $env:PATH = "$awsCliPath;$env:PATH"
    }

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

function Test-ExistingInstance {
    $existingId = aws ec2 describe-instances `
        --profile $AWS_PROFILE_NAME `
        --filters "Name=tag:Name,Values=$INSTANCE_NAME" "Name=instance-state-name,Values=running,stopped,pending" `
        --query "Reservations[].Instances[0].InstanceId" `
        --region $REGION `
        --output text 2>$null

    if ($existingId -and $existingId -ne "None") {
        Write-Host ""
        Write-Warn "An existing Kiro-LAB instance was found: $existingId"
        Write-Host ""
        Write-Host "  Deploying again will TERMINATE the existing instance and create a new one." -ForegroundColor Yellow
        Write-Host ""
        $confirm = Read-Host "  Do you want to continue? (The old instance will be deleted) [y/N]"
        if ($confirm -notmatch '^[Yy]$') {
            Write-Info "Deployment cancelled."
            exit 0
        }

        Write-Host ""
        # Terminate existing instance
        Write-Info "Terminating existing instance: $existingId (this may take a moment)..."
        aws ec2 terminate-instances `
            --profile $AWS_PROFILE_NAME `
            --instance-ids $existingId `
            --region $REGION | Out-Null
        aws ec2 wait instance-terminated `
            --profile $AWS_PROFILE_NAME `
            --instance-ids $existingId `
            --region $REGION 2>$null
        Write-Ok "Existing instance terminated."
    }
}

function Get-UbuntuAMI {
    Write-Info "Finding latest Ubuntu 26.04 AMI in $REGION..."

    # Try SSM parameter for Ubuntu 26.04
    $script:AMI_ID = aws ssm get-parameters `
        --profile $AWS_PROFILE_NAME `
        --names "/aws/service/canonical/ubuntu/server/26.04/stable/current/amd64/hvm/ebs-gp3/ami-id" `
        --region $REGION `
        --query "Parameters[0].Value" `
        --output text 2>$null

    if (-not $script:AMI_ID -or $script:AMI_ID -eq "None") {
        # Fallback: search by name pattern
        $script:AMI_ID = aws ec2 describe-images `
            --profile $AWS_PROFILE_NAME `
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
            --profile $AWS_PROFILE_NAME `
            --names "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id" `
            --region $REGION `
            --query "Parameters[0].Value" `
            --output text 2>$null

        if (-not $script:AMI_ID -or $script:AMI_ID -eq "None") {
            $script:AMI_ID = aws ec2 describe-images `
                --profile $AWS_PROFILE_NAME `
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
        --profile $AWS_PROFILE_NAME `
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
        --profile $AWS_PROFILE_NAME `
        --group-name $sgName `
        --description "Security group for Kiro-LAB SSH development instance" `
        --region $REGION `
        --output text --query "GroupId"

    # Allow SSH only
    aws ec2 authorize-security-group-ingress `
        --profile $AWS_PROFILE_NAME `
        --group-id $script:SG_ID `
        --protocol tcp --port 22 --cidr "0.0.0.0/0" `
        --region $REGION | Out-Null

    Write-Ok "Created security group: $script:SG_ID (SSH inbound only)"
}

function Get-Userdata {
    Write-Info "Preparing userdata script..."

    $tempPath = Join-Path $env:TEMP "kiro-lab-userdata.sh"

    # Check for local file (only when running as a script file, not via irm | iex)
    if ($PSScriptRoot) {
        $localPath = Join-Path $PSScriptRoot "userdata-kiro-lab.sh"
        if (Test-Path $localPath) {
            $script:USERDATA_PATH = $localPath
            Write-Info "Using local userdata script"
            return
        }
    }

    # Try download from remote
    try {
        Invoke-WebRequest -Uri $USERDATA_URL -OutFile $tempPath -UseBasicParsing -ErrorAction Stop
        $script:USERDATA_PATH = $tempPath
        Write-Info "Downloaded userdata from remote"
    }
    catch {
        # Write embedded userdata
        Write-Warn "Could not fetch userdata, using embedded version"
        $embeddedUserdata = @'
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
cat >> /home/ubuntu/.bashrc << 'EOF'
export PATH="$HOME/.local/bin:$HOME/.bun/bin:$PATH"
EOF
hostnamectl set-hostname kiro-lab
touch /home/ubuntu/.kiro-lab-ready && chown ubuntu:ubuntu /home/ubuntu/.kiro-lab-ready
'@
            Set-Content -Path $tempPath -Value $embeddedUserdata -Encoding UTF8 -NoNewline
            $script:USERDATA_PATH = $tempPath
    }

    # Final validation
    if (-not $script:USERDATA_PATH -or -not (Test-Path $script:USERDATA_PATH)) {
        Write-Err "Failed to prepare userdata script. Cannot proceed with deployment."
        exit 1
    }
    Write-Ok "Userdata ready: $($script:USERDATA_PATH)"
}

function Start-Instance {
    Write-Info "Launching EC2 instance ($INSTANCE_TYPE)..."

    $script:INSTANCE_ID = aws ec2 run-instances `
        --profile $AWS_PROFILE_NAME `
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

    if ($LASTEXITCODE -ne 0 -or -not $script:INSTANCE_ID -or $script:INSTANCE_ID -eq "None") {
        Write-Err "Failed to launch EC2 instance. Check your credentials and configuration."
        exit 1
    }

    Write-Ok "Instance launched: $script:INSTANCE_ID"

    Write-Info "Waiting for instance to enter running state..."
    aws ec2 wait instance-running --profile $AWS_PROFILE_NAME --instance-ids $script:INSTANCE_ID --region $REGION
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Instance failed to reach running state. Check the AWS console for details."
        Write-Err "Instance ID: $script:INSTANCE_ID"
        exit 1
    }
    Write-Ok "Instance is running!"
}

function New-ElasticIP {
    Write-Info "Allocating Elastic IP..."

    # Check if an EIP tagged for Kiro-LAB already exists
    $script:ALLOCATION_ID = aws ec2 describe-addresses `
        --profile $AWS_PROFILE_NAME `
        --filters "Name=tag:Name,Values=$INSTANCE_NAME" `
        --query "Addresses[0].AllocationId" `
        --region $REGION `
        --output text 2>$null

    if ($script:ALLOCATION_ID -and $script:ALLOCATION_ID -ne "None") {
        Write-Ok "Reusing existing Elastic IP allocation: $script:ALLOCATION_ID"
    } else {
        # Allocate a new Elastic IP
        $script:ALLOCATION_ID = aws ec2 allocate-address `
            --profile $AWS_PROFILE_NAME `
            --domain vpc `
            --tag-specifications "ResourceType=elastic-ip,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" `
            --region $REGION `
            --query "AllocationId" `
            --output text

        if ($LASTEXITCODE -ne 0 -or -not $script:ALLOCATION_ID -or $script:ALLOCATION_ID -eq "None") {
            Write-Err "Failed to allocate Elastic IP."
            exit 1
        }
        Write-Ok "Allocated new Elastic IP: $script:ALLOCATION_ID"
    }

    # Associate EIP with the instance
    Write-Info "Associating Elastic IP with instance $($script:INSTANCE_ID)..."
    aws ec2 associate-address `
        --profile $AWS_PROFILE_NAME `
        --allocation-id $script:ALLOCATION_ID `
        --instance-id $script:INSTANCE_ID `
        --region $REGION | Out-Null

    if ($LASTEXITCODE -ne 0) {
        Write-Err "Failed to associate Elastic IP with instance."
        exit 1
    }
    Write-Ok "Elastic IP associated with instance."
}

function Get-InstanceDNS {
    Write-Info "Getting instance Elastic IP address..."

    Start-Sleep -Seconds 3

    $script:PUBLIC_IP = aws ec2 describe-addresses `
        --profile $AWS_PROFILE_NAME `
        --allocation-ids $script:ALLOCATION_ID `
        --query "Addresses[0].PublicIp" `
        --region $REGION `
        --output text

    $script:PUBLIC_DNS = aws ec2 describe-instances `
        --profile $AWS_PROFILE_NAME `
        --instance-ids $script:INSTANCE_ID `
        --query "Reservations[0].Instances[0].PublicDnsName" `
        --region $REGION `
        --output text

    if (-not $script:PUBLIC_DNS -or $script:PUBLIC_DNS -eq "None") {
        $script:PUBLIC_DNS = $script:PUBLIC_IP
    }

    Write-Ok "Elastic IP: $script:PUBLIC_IP"
    Write-Ok "Public DNS: $script:PUBLIC_DNS"
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
    Write-Host "  Elastic IP:    $($script:PUBLIC_IP) (persists across lab restarts)"
    Write-Host "  Public DNS:    $($script:PUBLIC_DNS)"
    Write-Host "  Instance Type: $INSTANCE_TYPE"
    Write-Host "  Region:        $REGION"
    Write-Host "  AWS Profile:   $AWS_PROFILE_NAME"
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
    Write-Host "  To clean up all resources later:" -ForegroundColor Cyan
    Write-Host "    .\deploy-kiro-lab.ps1 -Action cleanup"
    Write-Host ""
    Write-Host "==============================================================" -ForegroundColor Green
}

# ─── Cleanup ─────────────────────────────────────────────────────────────────

function Invoke-Cleanup {
    Write-Host ""
    Write-Host "+===========================================+" -ForegroundColor Yellow
    Write-Host "|   Kiro-LAB Cleanup                        |" -ForegroundColor Yellow
    Write-Host "+===========================================+" -ForegroundColor Yellow
    Write-Host ""

    # Check prerequisites
    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        Write-Err "AWS CLI not found. Cannot perform cleanup."
        exit 1
    }

    # Check profile exists and is valid
    $null = aws sts get-caller-identity --profile $AWS_PROFILE_NAME --output json 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Err "AWS profile '$AWS_PROFILE_NAME' is not configured or credentials are expired."
        Write-Host "  Please run the deploy script first to configure credentials,"
        Write-Host "  or manually configure the profile:"
        Write-Host "    aws configure --profile $AWS_PROFILE_NAME"
        exit 1
    }

    Write-Info "This will remove the following resources:"
    Write-Host ""

    # Find instances
    $instanceIds = aws ec2 describe-instances `
        --profile $AWS_PROFILE_NAME `
        --filters "Name=tag:Name,Values=$INSTANCE_NAME" "Name=instance-state-name,Values=running,stopped,pending" `
        --query "Reservations[].Instances[].InstanceId" `
        --region $REGION `
        --output text 2>$null

    if ($instanceIds -and $instanceIds -ne "None") {
        Write-Host "  * EC2 Instance(s): $instanceIds"
    } else {
        Write-Host "  * EC2 Instance(s): (none found)"
        $instanceIds = $null
    }

    # Find security group
    $sgId = aws ec2 describe-security-groups `
        --profile $AWS_PROFILE_NAME `
        --filters "Name=group-name,Values=kiro-lab-sg" `
        --query "SecurityGroups[0].GroupId" `
        --region $REGION `
        --output text 2>$null

    if ($sgId -and $sgId -ne "None") {
        Write-Host "  * Security Group: $sgId (kiro-lab-sg)"
    } else {
        Write-Host "  * Security Group: (none found)"
        $sgId = $null
    }

    # Find Elastic IP
    $eipAllocId = aws ec2 describe-addresses `
        --profile $AWS_PROFILE_NAME `
        --filters "Name=tag:Name,Values=$INSTANCE_NAME" `
        --query "Addresses[0].AllocationId" `
        --region $REGION `
        --output text 2>$null
    $eipAddress = aws ec2 describe-addresses `
        --profile $AWS_PROFILE_NAME `
        --filters "Name=tag:Name,Values=$INSTANCE_NAME" `
        --query "Addresses[0].PublicIp" `
        --region $REGION `
        --output text 2>$null

    if ($eipAllocId -and $eipAllocId -ne "None") {
        Write-Host "  * Elastic IP: $eipAddress ($eipAllocId)"
    } else {
        Write-Host "  * Elastic IP: (none found)"
        $eipAllocId = $null
    }

    $sshConfig = Join-Path $env:USERPROFILE ".ssh\config"
    Write-Host "  * SSH Config: 'kiro-lab' entry in $sshConfig"
    Write-Host "  * AWS Profile: '$AWS_PROFILE_NAME' from ~/.aws/credentials and ~/.aws/config"
    Write-Host ""

    $confirm = Read-Host "  Are you sure you want to delete all these resources? [y/N]"
    if ($confirm -notmatch '^[Yy]$') {
        Write-Info "Cleanup cancelled."
        exit 0
    }

    Write-Host ""
    Write-Info "Starting cleanup process..."
    Write-Host ""

    # Terminate instances
    if ($instanceIds) {
        Write-Info "Terminating EC2 instance(s): $instanceIds ..."
        aws ec2 terminate-instances `
            --profile $AWS_PROFILE_NAME `
            --instance-ids $instanceIds `
            --region $REGION | Out-Null
        Write-Info "Waiting for instance(s) to terminate..."
        aws ec2 wait instance-terminated `
            --profile $AWS_PROFILE_NAME `
            --instance-ids $instanceIds `
            --region $REGION 2>$null
        Write-Ok "Instance(s) terminated."
    }

    # Release Elastic IP
    if ($eipAllocId) {
        Write-Info "Releasing Elastic IP: $eipAddress ($eipAllocId) ..."
        # Disassociate first if still associated
        $assocId = aws ec2 describe-addresses `
            --profile $AWS_PROFILE_NAME `
            --allocation-ids $eipAllocId `
            --query "Addresses[0].AssociationId" `
            --region $REGION `
            --output text 2>$null
        if ($assocId -and $assocId -ne "None") {
            aws ec2 disassociate-address `
                --profile $AWS_PROFILE_NAME `
                --association-id $assocId `
                --region $REGION 2>$null | Out-Null
        }
        aws ec2 release-address `
            --profile $AWS_PROFILE_NAME `
            --allocation-id $eipAllocId `
            --region $REGION 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Ok "Elastic IP released."
        } else {
            Write-Warn "Could not release Elastic IP. You can release it manually:"
            Write-Warn "  aws ec2 release-address --allocation-id $eipAllocId --region $REGION --profile $AWS_PROFILE_NAME"
        }
    }

    # Delete security group (may need retry as ENIs detach)
    if ($sgId) {
        Write-Info "Deleting security group: $sgId ..."
        $retries = 0
        $deleted = $false
        while ($retries -lt 5) {
            $null = aws ec2 delete-security-group `
                --profile $AWS_PROFILE_NAME `
                --group-id $sgId `
                --region $REGION 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Ok "Security group deleted."
                $deleted = $true
                break
            }
            $retries++
            if ($retries -lt 5) {
                Write-Warn "Security group still in use, retrying in 10s... ($retries/5)"
                Start-Sleep -Seconds 10
            }
        }
        if (-not $deleted) {
            Write-Warn "Could not delete security group. It may still be attached to a network interface."
            Write-Warn "You can delete it manually: aws ec2 delete-security-group --group-id $sgId --region $REGION --profile $AWS_PROFILE_NAME"
        }
    }

    # Remove SSH config entry
    if (Test-Path $sshConfig) {
        $content = Get-Content $sshConfig -Raw
        if ($content -match '# >>> Kiro-LAB >>>') {
            $content = $content -replace '(?s)\r?\n?# >>> Kiro-LAB >>>.*?# <<< Kiro-LAB <<<\r?\n?', ''
            Set-Content -Path $sshConfig -Value $content.TrimEnd() -Encoding UTF8 -NoNewline
            Write-Ok "SSH config entry removed."
        }
    }

    # Remove AWS profile
    Write-Info "Removing AWS profile '$AWS_PROFILE_NAME'..."
    $credFile = Join-Path $env:USERPROFILE ".aws\credentials"
    $configFile = Join-Path $env:USERPROFILE ".aws\config"

    if (Test-Path $credFile) {
        $lines = Get-Content $credFile
        $newLines = @()
        $skip = $false
        foreach ($line in $lines) {
            if ($line -match "^\[$AWS_PROFILE_NAME\]") {
                $skip = $true
                continue
            }
            if ($skip -and $line -match '^\[') {
                $skip = $false
            }
            if (-not $skip) {
                $newLines += $line
            }
        }
        Set-Content -Path $credFile -Value ($newLines -join "`n") -Encoding UTF8 -NoNewline
    }

    if (Test-Path $configFile) {
        $lines = Get-Content $configFile
        $newLines = @()
        $skip = $false
        foreach ($line in $lines) {
            if ($line -match "^\[profile $AWS_PROFILE_NAME\]") {
                $skip = $true
                continue
            }
            if ($skip -and $line -match '^\[') {
                $skip = $false
            }
            if (-not $skip) {
                $newLines += $line
            }
        }
        Set-Content -Path $configFile -Value ($newLines -join "`n") -Encoding UTF8 -NoNewline
    }
    Write-Ok "AWS profile removed."

    Write-Host ""
    Write-Host "==============================================================" -ForegroundColor Green
    Write-Host "  Kiro-LAB Cleanup Complete!" -ForegroundColor Green
    Write-Host "==============================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  All Kiro-LAB resources have been removed."
    Write-Host ""
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
    Test-ExistingInstance
    Collect-SSHKey
    Get-UbuntuAMI
    New-SecurityGroup
    Get-Userdata
    Start-Instance
    New-ElasticIP
    Get-InstanceDNS
    Set-SSHConfig
    Show-Summary
}

# ─── Entry Point ─────────────────────────────────────────────────────────────

switch ($Action) {
    { $_ -in "cleanup", "clean", "destroy", "teardown" } {
        Test-Prerequisites
        Invoke-Cleanup
    }
    default {
        Main
    }
}
