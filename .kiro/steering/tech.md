# Tech Stack

## Runtime
- Node.js (v22.x on Amazon Linux 2023)
- npm for package management

## Framework & Libraries
- **Express 4.x** — HTTP server and routing
- **Mustache Express** — server-side HTML templating (`.html` files with Mustache syntax)
- **mysql2** — MySQL database driver
- **express-validator** — request body validation and sanitization
- **body-parser** — JSON and URL-encoded form parsing
- **cors** — Cross-Origin Resource Sharing middleware
- **serve-favicon** — favicon serving
- **aws-sdk** — AWS Secrets Manager integration for database credentials

## Frontend
- Bootstrap (CSS + JS, served statically)
- jQuery 3.6.0
- Custom CSS in `public/css/base.css`

## RDS Configuration
- Database: `STUDENTS`
- Manage credentials using AWS Secrets Manager, Secret name: `Mydbsecret`

## AWS Secrets Manager Configuration
- User: `nodeapp`
- Password: `student12`
- Secret name: `Mydbsecret`

## Default AWS Configuration
EC2 Key pair: vockey
AWS IAM Constraints: All AWS deployments MUST use `LabRole`. Do NOT create or refer to any other IAM resources
IAM Instance profile: LabInstanceProfile

## AWS Architecture (MVP Deployment)
Use a simple architecture for the MVP, consisting of the following components:

- **EC2 + Elastic IP (EIP)** — runs the Node.js/Express application on Amazon Linux 2023
  - Application listens on port 80 in production (configurable via `APP_PORT`)
  - An Elastic IP (EIP) is associated with the instance to provide a static public IP
  - Uses the IAM Instance profile `LabInstanceProfile` (role `LabRole`) to access AWS Secrets Manager
  - Uses the EC2 Key pair `vockey` for SSH access
- **RDS Aurora MySQL** — the primary database (database `STUDENTS`, table `students`)
  - Credentials are stored in AWS Secrets Manager (secret name `Mydbsecret`)
  - EC2 connects to Aurora MySQL through its endpoint within the VPC

Note: This is an MVP-level architecture focused on simplicity. It does not include a load balancer, auto scaling, or multi-AZ redundancy.


## Common Commands

```bash
# ----------------------------
# Node.js 22 LTS (via NodeSource RPM setup)
# ----------------------------
curl -fsSL --retry 3 --retry-delay 5 https://rpm.nodesource.com/setup_22.x | bash -
dnf_retry install nodejs
npm install -g npm@latest || true  # May fail if npm version requires newer Node.js


# Start the application (requires DB env vars or Secrets Manager access)
npm start

# Environment variables used:
# APP_DB_HOST - MySQL host address
# APP_DB_USER - MySQL username (default: nodeapp)
# APP_DB_PASSWORD - MySQL password (default: student12)
# APP_DB_NAME - Database name (default: STUDENTS)
# APP_PORT - Server port (default: 3000)
```

## Configuration
- Database config lives in `app/config/config.js`
- Credentials are loaded from AWS Secrets Manager first; falls back to hardcoded defaults if unavailable
- Environment variables override defaults when set


