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


## Common Commands

```bash
# Install dependencies
npm install

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


