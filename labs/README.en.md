# Kiro-LAB: EC2 Instance for Remote SSH Development

[🇹🇭 ภาษาไทย](./README.md) | 🇬🇧 **English**

Create an EC2 instance for using Kiro IDE through the Remote SSH extension.

> **Note on language:** By default, Kiro replies in **Thai** because of the steering file [`.kiro/steering/communication.md`](../.kiro/steering/communication.md). If you'd prefer Kiro to reply in **English**, see [Switching Kiro's Reply Language to English](#switching-kiros-reply-language-to-english) below.

## Choose a Script Set (Ubuntu or Amazon Linux)

Two deploy script sets are available. They behave identically (Dev tools, MCP config, Elastic IP, how to connect Kiro IDE) and differ only in the instance OS:

| Set | OS | Package Manager | Default User | Root Device | Best for |
|-----|-----|-----------------|--------------|-------------|----------|
| `deploy-kiro-lab.{sh,ps1}` | Ubuntu 26.04 (fallback 24.04) | `apt` | `ubuntu` | `/dev/sda1` | The workshop's original default |
| `deploy-kiro-lab-al2023.{sh,ps1}` | Amazon Linux 2023 | `dnf` | `ec2-user` | `/dev/xvda` | **Recommended** — avoids slow `apt update` on AWS |

> **Why an Amazon Linux set exists:** Sometimes `apt update`/`apt upgrade` on AWS Ubuntu runs slowly or hangs during userdata setup, making the instance take longer to be ready. Amazon Linux 2023 uses `dnf`, which is faster and doesn't have the apt-style package-manager lock issues at boot. Both sets include retry/timeout logic to tolerate unstable networks.

## Prerequisites

- AWS CLI (if you don't have it, the script installs it automatically)
- AWS Academy Lab credentials (the script prompts you to enter them)
- SSH private key `vockey.pem` from the AWS Academy Lab (the script prompts you to paste it)

## Dev Tools Installed

| Tool | Description |
|------|-------------|
| Node.js 20 LTS | JavaScript runtime |
| npm | Node package manager |
| Bun | Fast JavaScript runtime & bundler |
| uv / uvx | Python package manager (replaces pip) |
| graphify | Knowledge graph tool (`uv tool install graphifyy`) |
| git | Version control |
| AWS CLI v2 | AWS command line interface |

## How to Use

Pick one of the two sets — Amazon Linux (`-al2023`) is recommended because setup is faster.

### macOS / Linux

```bash
# Amazon Linux 2023 (recommended)
curl -fsSL https://github.com/chaisit/aws-kiro-workshop/raw/refs/heads/main/labs/deploy-kiro-lab-al2023.sh | bash
```
or
```bash
# Ubuntu
curl -fsSL https://github.com/chaisit/aws-kiro-workshop/raw/refs/heads/main/labs/deploy-kiro-lab.sh | bash
```

### Windows (PowerShell)

```powershell
# Amazon Linux 2023 (recommended)
irm https://github.com/chaisit/aws-kiro-workshop/raw/refs/heads/main/labs/deploy-kiro-lab-al2023.ps1 | iex
```
or
```powershell
# Ubuntu
irm https://github.com/chaisit/aws-kiro-workshop/raw/refs/heads/main/labs/deploy-kiro-lab.ps1 | iex
```

## What the Script Does

1. Checks for the AWS CLI (installs it automatically if missing)
2. Prompts for AWS credentials (access key, secret key, session token)
3. Prompts for the SSH private key (paste it directly, or use an existing file)
4. Finds the latest AMI (Ubuntu 26.04 with 24.04 fallback / or Amazon Linux 2023, depending on the chosen set)
5. Creates a Security Group (SSH inbound only)
6. Creates the EC2 instance (t3.medium, 30GB gp3)
7. Waits until the instance is running
8. Allocates an Elastic IP and associates it with the instance
9. Automatically creates an SSH config entry (`~/.ssh/config`)

## Elastic IP (Static IP)

The script automatically allocates an **Elastic IP** for the instance to solve the problem of the public IP changing when the AWS Academy Lab session stops and starts again.

**Benefits:**
- A fixed IP address that doesn't change when the instance stops/starts
- No need to edit the SSH config every time the Lab restarts
- Kiro IDE Remote SSH can connect immediately after the Lab starts again

**Behavior:**
- First deploy: allocates a new EIP (tagged `Kiro-LAB`)
- Repeat deploy: reuses the existing EIP (no new allocation)
- Cleanup: releases the EIP automatically

## Connect Kiro IDE

After the script runs successfully:

1. Open **Kiro IDE**
2. Install the **Remote - SSH** extension (if not already installed)
3. Press `Ctrl+Shift+P` → type `Remote-SSH: Connect to Host...`
4. Select **`kiro-lab`**
5. Open the folder: `/home/ubuntu/workshop` (Ubuntu) or `/home/ec2-user/workshop` (Amazon Linux)

Or use the SSH command directly:

```bash
ssh kiro-lab
```

## Check Status

The instance takes ~3-5 minutes to install all dev tools.

```bash
# View the installation log
ssh kiro-lab 'tail -f /var/log/userdata-kiro-lab.log'

# Check whether it's ready
ssh kiro-lab 'ls ~/.kiro-lab-ready 2>/dev/null && echo READY || echo NOT READY'
```

## MCP Server (pre-configured)

The instance comes with an MCP config for Kiro:

- **aws-docs** — AWS Documentation MCP Server (run via `uvx`)

The config is located at: `~/.kiro/settings/mcp.json`

## EC2 Instance Specs

| Property | Value |
|----------|-------|
| Name | Kiro-LAB |
| Type | t3.medium (2 vCPU, 4 GB RAM) |
| OS | Ubuntu 26.04 LTS (fallback: 24.04) or Amazon Linux 2023 |
| Storage | 30 GB gp3 (encrypted) |
| Key Pair | vockey |
| IAM Profile | LabInstanceProfile |
| Security Group | kiro-lab-sg (SSH inbound only) |
| Elastic IP | Yes (static IP, persists across stop/start) |

## Files in This Folder

```
labs/
├── README.md                        # Thai version
├── README.en.md                     # This file (English)
├── deploy-kiro-lab.sh               # Ubuntu — Script for macOS/Linux
├── deploy-kiro-lab.ps1              # Ubuntu — Script for Windows (PowerShell)
├── userdata-kiro-lab.sh             # Ubuntu — EC2 userdata (apt)
├── deploy-kiro-lab-al2023.sh        # Amazon Linux 2023 — Script for macOS/Linux
├── deploy-kiro-lab-al2023.ps1       # Amazon Linux 2023 — Script for Windows (PowerShell)
└── userdata-kiro-lab-al2023.sh      # Amazon Linux 2023 — EC2 userdata (dnf)
```

## Switching Kiro's Reply Language to English

This repository ships with a Kiro steering file at [`.kiro/steering/communication.md`](../.kiro/steering/communication.md) that instructs Kiro to always reply in **Thai**. If you'd rather have Kiro communicate in **English**, edit that file and replace the references to `Thai` with `English`.

Open `.kiro/steering/communication.md` and change it to:

```markdown
---
inclusion: always
---

# Communication Language

- Always respond to the user in **English** language.
- Use English for explanations, summaries, questions, and all conversational text.
- Keep technical terms (e.g., variable names, file paths, command names, code snippets) in English as-is.
- Code comments may remain in English unless the user requests otherwise.
```

After saving the file, Kiro applies the updated steering automatically on your next message (no restart required). If you want to keep the original Thai default, simply leave the file unchanged.

> **Tip:** Steering files with `inclusion: always` are applied to every Kiro interaction in this workspace. You can also delete this file entirely if you don't want any language preference enforced.

## Cleanup

To delete the instance and all resources:

```bash
# Use the built-in cleanup command (recommended — removes instance, EIP, security group, SSH config, AWS profile)
# Clean up with the same set you deployed with (both sets remove resources named Kiro-LAB)
bash deploy-kiro-lab.sh cleanup
bash deploy-kiro-lab-al2023.sh cleanup
```

Or delete manually:

```bash
# Get the instance ID
aws ec2 describe-instances --filters "Name=tag:Name,Values=Kiro-LAB" \
  --query 'Reservations[].Instances[].InstanceId' --output text

# Terminate
aws ec2 terminate-instances --instance-ids <INSTANCE_ID>

# Release the Elastic IP
aws ec2 describe-addresses --filters "Name=tag:Name,Values=Kiro-LAB" \
  --query 'Addresses[].AllocationId' --output text
aws ec2 release-address --allocation-id <ALLOCATION_ID>

# Delete the security group (wait for the instance to terminate first)
aws ec2 delete-security-group --group-name kiro-lab-sg
```

Remove the SSH config entry:

```bash
# macOS/Linux - remove the lines between the markers
sed -i '/# >>> Kiro-LAB >>>/,/# <<< Kiro-LAB <<</d' ~/.ssh/config
```
