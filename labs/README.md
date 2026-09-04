# Kiro-LAB: EC2 Instance for Remote SSH Development

สร้าง EC2 instance สำหรับใช้งาน Kiro IDE ผ่าน Remote SSH extension

## เลือกชุด Script (Ubuntu หรือ Amazon Linux)

มี deploy script ให้เลือก 2 ชุด ทำงานเหมือนกันทุกอย่าง (Dev tools, MCP config, Elastic IP, วิธีเชื่อมต่อ Kiro IDE) ต่างกันแค่ OS ของ instance:

| ชุด | OS | Package Manager | Default User | Root Device | เหมาะกับ |
|-----|-----|-----------------|--------------|-------------|----------|
| `deploy-kiro-lab.{sh,ps1}` | Ubuntu 26.04 (fallback 24.04) | `apt` | `ubuntu` | `/dev/sda1` | ค่าเริ่มต้นเดิมของ workshop |
| `deploy-kiro-lab-al2023.{sh,ps1}` | Amazon Linux 2023 | `dnf` | `ec2-user` | `/dev/xvda` | **แนะนำ** — เลี่ยงปัญหา `apt update` ช้าบน AWS |

> **ทำไมถึงมีชุด Amazon Linux:** บางครั้ง `apt update`/`apt upgrade` บน Ubuntu ของ AWS ทำงานช้าหรือค้างระหว่าง userdata setup ทำให้ instance ใช้เวลานานกว่าจะพร้อม Amazon Linux 2023 ใช้ `dnf` ซึ่งเร็วกว่าและไม่มีปัญหา package-manager lock ตอน boot แบบ apt ทั้งสองชุดใส่ retry/timeout ให้ทนต่อ network ที่ไม่เสถียรไว้แล้ว

## สิ่งที่ต้องมีก่อนใช้งาน

- AWS CLI (ถ้ายังไม่มี script จะติดตั้งให้อัตโนมัติ)
- AWS Academy Lab credentials (script จะถามให้กรอก)
- SSH private key `vockey.pem` จาก AWS Academy Lab (script จะถามให้ paste)

## Dev Tools ที่ติดตั้งให้

| Tool | Description |
|------|-------------|
| Node.js 20 LTS | JavaScript runtime |
| npm | Node package manager |
| Bun | Fast JavaScript runtime & bundler |
| uv / uvx | Python package manager (replaces pip) |
| graphify | Knowledge graph tool (`uv tool install graphifyy`) |
| git | Version control |
| AWS CLI v2 | AWS command line interface |

## วิธีใช้งาน

เลือกใช้ชุดใดชุดหนึ่ง — Amazon Linux (`-al2023`) แนะนำเพราะ setup เร็วกว่า

### macOS / Linux

```bash
# Amazon Linux 2023 (แนะนำ)
curl -fsSL https://github.com/chaisit/aws-kiro-workshop/raw/refs/heads/main/labs/deploy-kiro-lab-al2023.sh | bash
```
หรือ
```bash
# Ubuntu
curl -fsSL https://github.com/chaisit/aws-kiro-workshop/raw/refs/heads/main/labs/deploy-kiro-lab.sh | bash
```

### Windows (PowerShell)

```powershell
# Amazon Linux 2023 (แนะนำ)
irm https://github.com/chaisit/aws-kiro-workshop/raw/refs/heads/main/labs/deploy-kiro-lab-al2023.ps1 | iex
```
หรือ
```powershell
# Ubuntu
irm https://github.com/chaisit/aws-kiro-workshop/raw/refs/heads/main/labs/deploy-kiro-lab.ps1 | iex
```

## Script ทำอะไรบ้าง

1. ตรวจสอบ AWS CLI (ถ้าไม่มี → ติดตั้งให้อัตโนมัติ)
2. ถาม AWS credentials (access key, secret key, session token)
3. ถาม SSH private key (paste ได้เลย หรือใช้ไฟล์ที่มีอยู่)
4. หา AMI ล่าสุด (Ubuntu 26.04 fallback 24.04 / หรือ Amazon Linux 2023 แล้วแต่ชุดที่เลือก)
5. สร้าง Security Group (SSH inbound only)
6. สร้าง EC2 instance (t3.medium, 30GB gp3)
7. รอจนกว่า instance จะ running
8. จัดสรร Elastic IP และ associate กับ instance
9. สร้าง SSH config entry อัตโนมัติ (`~/.ssh/config`)

## Elastic IP (Static IP)

Script จะจัดสรร **Elastic IP** ให้กับ instance โดยอัตโนมัติ เพื่อแก้ปัญหา public IP เปลี่ยนเมื่อ AWS Academy Lab session หยุดแล้ว start ใหม่

**ข้อดี:**
- IP address คงที่ ไม่เปลี่ยนเมื่อ instance stop/start
- ไม่ต้องแก้ SSH config ทุกครั้งที่ Lab restart
- Kiro IDE Remote SSH เชื่อมต่อได้ทันทีหลัง Lab start ใหม่

**พฤติกรรม:**
- Deploy ครั้งแรก: จัดสรร EIP ใหม่ (tagged ชื่อ `Kiro-LAB`)
- Deploy ซ้ำ: ใช้ EIP เดิมที่มีอยู่ (ไม่จัดสรรใหม่)
- Cleanup: ปล่อย EIP คืน (release) โดยอัตโนมัติ

## เชื่อมต่อ Kiro IDE

หลังจากรัน script สำเร็จ:

1. เปิด **Kiro IDE**
2. ติดตั้ง extension **Remote - SSH** (ถ้ายังไม่มี)
3. กด `Ctrl+Shift+P` → พิมพ์ `Remote-SSH: Connect to Host...`
4. เลือก **`kiro-lab`**
5. เปิดโฟลเดอร์: `/home/ubuntu/workshop` (Ubuntu) หรือ `/home/ec2-user/workshop` (Amazon Linux)

หรือใช้คำสั่ง SSH ตรงๆ:

```bash
ssh kiro-lab
```

## ตรวจสอบสถานะ

Instance ใช้เวลา ~3-5 นาทีในการติดตั้ง dev tools ทั้งหมด

```bash
# ดู log การติดตั้ง
ssh kiro-lab 'tail -f /var/log/userdata-kiro-lab.log'

# ตรวจสอบว่าพร้อมใช้งาน
ssh kiro-lab 'ls ~/.kiro-lab-ready 2>/dev/null && echo READY || echo NOT READY'
```

## MCP Server (pre-configured)

Instance มาพร้อม MCP config สำหรับ Kiro:

- **aws-docs** — AWS Documentation MCP Server (ใช้ `uvx` run)

Config อยู่ที่: `~/.kiro/settings/mcp.json`

## EC2 Instance Specs

| Property | Value |
|----------|-------|
| Name | Kiro-LAB |
| Type | t3.medium (2 vCPU, 4 GB RAM) |
| OS | Ubuntu 26.04 LTS (fallback: 24.04) หรือ Amazon Linux 2023 |
| Storage | 30 GB gp3 (encrypted) |
| Key Pair | vockey |
| IAM Profile | LabInstanceProfile |
| Security Group | kiro-lab-sg (SSH inbound only) |
| Elastic IP | Yes (static IP, persists across stop/start) |

## ไฟล์ในโฟลเดอร์นี้

```
labs/
├── README.md                        # ไฟล์นี้
├── deploy-kiro-lab.sh               # Ubuntu — Script สำหรับ macOS/Linux
├── deploy-kiro-lab.ps1              # Ubuntu — Script สำหรับ Windows (PowerShell)
├── userdata-kiro-lab.sh             # Ubuntu — EC2 userdata (apt)
├── deploy-kiro-lab-al2023.sh        # Amazon Linux 2023 — Script สำหรับ macOS/Linux
├── deploy-kiro-lab-al2023.ps1       # Amazon Linux 2023 — Script สำหรับ Windows (PowerShell)
└── userdata-kiro-lab-al2023.sh      # Amazon Linux 2023 — EC2 userdata (dnf)
```

## Cleanup

หากต้องการลบ instance และ resources ทั้งหมด:

```bash
# ใช้ built-in cleanup command (แนะนำ — ลบ instance, EIP, security group, SSH config, AWS profile)
# ใช้ชุดไหน deploy ก็ cleanup ด้วยชุดนั้น (ทั้งสองชุดลบ resource ชื่อ Kiro-LAB เหมือนกัน)
bash deploy-kiro-lab.sh cleanup
bash deploy-kiro-lab-al2023.sh cleanup
```

หรือลบ manual:

```bash
# ดู instance ID
aws ec2 describe-instances --filters "Name=tag:Name,Values=Kiro-LAB" \
  --query 'Reservations[].Instances[].InstanceId' --output text

# Terminate
aws ec2 terminate-instances --instance-ids <INSTANCE_ID>

# Release Elastic IP
aws ec2 describe-addresses --filters "Name=tag:Name,Values=Kiro-LAB" \
  --query 'Addresses[].AllocationId' --output text
aws ec2 release-address --allocation-id <ALLOCATION_ID>

# ลบ security group (รอ instance terminate ก่อน)
aws ec2 delete-security-group --group-name kiro-lab-sg
```

ลบ SSH config entry:

```bash
# macOS/Linux - ลบบรรทัดระหว่าง markers
sed -i '/# >>> Kiro-LAB >>>/,/# <<< Kiro-LAB <<</d' ~/.ssh/config
```
