# Kiro-LAB: EC2 Instance for Remote SSH Development

สร้าง EC2 instance สำหรับใช้งาน Kiro IDE ผ่าน Remote SSH extension

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
| graphify | Knowledge graph tool (`uv tool install graphify`) |
| git | Version control |
| AWS CLI v2 | AWS command line interface |

## วิธีใช้งาน

### macOS / Linux

```bash
# Option 1: Run directly
bash deploy-kiro-lab.sh

# Option 2: curl and run
curl -fsSL https://github.com/chaisit/aws-kiro-workshop/raw/refs/heads/main/labs/deploy-kiro-lab.sh | bash
```

### Windows (PowerShell)

```powershell
# Option 1: Run directly
.\deploy-kiro-lab.ps1

# Option 2: Download and run
irm https://github.com/chaisit/aws-kiro-workshop/raw/refs/heads/main/labs/deploy-kiro-lab.ps1 | iex
```

## Script ทำอะไรบ้าง

1. ตรวจสอบ AWS CLI (ถ้าไม่มี → ติดตั้งให้อัตโนมัติ)
2. ถาม AWS credentials (access key, secret key, session token)
3. ถาม SSH private key (paste ได้เลย หรือใช้ไฟล์ที่มีอยู่)
4. หา Ubuntu 26.04 AMI ล่าสุด (fallback เป็น 24.04 ถ้ายังไม่มี)
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
5. เปิดโฟลเดอร์: `/home/ubuntu/workshop`

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
| OS | Ubuntu 26.04 LTS (fallback: 24.04) |
| Storage | 30 GB gp3 (encrypted) |
| Key Pair | vockey |
| IAM Profile | LabInstanceProfile |
| Security Group | kiro-lab-sg (SSH inbound only) |
| Elastic IP | Yes (static IP, persists across stop/start) |

## ไฟล์ในโฟลเดอร์นี้

```
labs/
├── README.md                 # ไฟล์นี้
├── deploy-kiro-lab.sh        # Script สำหรับ macOS/Linux
├── deploy-kiro-lab.ps1       # Script สำหรับ Windows (PowerShell)
└── userdata-kiro-lab.sh      # EC2 userdata (ติดตั้ง dev tools)
```

## Cleanup

หากต้องการลบ instance และ resources ทั้งหมด:

```bash
# ใช้ built-in cleanup command (แนะนำ — ลบ instance, EIP, security group, SSH config, AWS profile)
bash deploy-kiro-lab.sh cleanup
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
