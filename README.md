# Gitea to S3 Backup Solution 🔄☁️


Automated backup solution for Gitea that compresses repositories and databases, then securely uploads to AWS S3.


## ⚡ Quick Start

```bash
# Clone the repository
git clone https://github.com/rajeshrj-git/Gitea_to_S3_Bucket.git
cd Gitea_to_S3_Bucket


# Setup environment (edit with your values)
cp .env.example .env
nano .env  # Add your credentials

# Make executable and run
chmod +x gitea_to_s3.sh
./gitea_to_s3.sh


## 🔧 Configuration:

#Required .env Variables

#!/bin/bash


# Database Configuration
DB_USER="DB_USER_NAME" #eg:gitea_user
DB_PASS="YOUR_PASS"  
DB_NAME="YOUR_DB_NAME"  # eg:gitea_db
DB_HOST="YOUR_HOST" #eg:localhost

# Gitea Configuration
REPO_DIR="GITEA_REPO_NAME" #/var/lib/gitea/data/gitea-repositories


# AWS S3 Configuration
AWS_ACCESS_KEY_ID="YOUR_AWS_ACCESS_KEY_ID"
AWS_SECRET_ACCESS_KEY="YOUR_AWS_SECRET_ACCESS_KEY"
AWS_DEFAULT_REGION="YOUR_REGION" #eg:ap-south-1
S3_BUCKET="YOUR_S3_BUCKET_NAME"
S3_PATH="" #its not nessasary to fill this option



TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="gitea_backup_${TIMESTAMP}.zip"
TMP_DIR=$(mktemp -d -t gitea_backup_XXXXXX)
LOG_FILE="YOUR_LOG_FILE_NAME.log"


🛡️ Security Best Practices:

# 1.File Permissions:

chmod 600 .env  # Restrict to owner only


#2.Git Protection
echo ".env" >> .gitignore




📆 Automation [Optional]
#Cron Job (Daily at 12AM)

0 12 * * * /path/to/Gitea_to_S3_Bucket/gitea_to_s3.sh >> /var/log/gitea_backup.log 2>&1

