# 🚀 Gitea Repository Backup to S3

A handy script to **backup all Gitea repositories** and *database*, and optionally push them to **Amazon S3** or store locally.
🛠️ Designed for admins who want peace of mind and automation.

---

## 📢 Important: First-Time Setup

> ⚠️ **Always run this script as the ********************************`root`******************************** user** during the first setup to avoid permission issues.

---

## 📦 Files Overview

* `gitea_to_s3.sh` – Main script to backup repositories and optionally upload to S3.
* `credential_config.sh` – 🔐 Stores your S3 credentials or local backup destination configuration.

---

## 🛠️ Setup Instructions

### 1️⃣ Switch to Root (if not already)

```bash
sudo -i
```

### 2️⃣ Clone or Copy the Project

```bash
git clone https://github.com/rajeshrj-git/Gitea_to_S3_Bucket/tree/main

```

### 3️⃣ Add Your Credentials

Edit the `credential_config.sh` file and provide your configuration:

```bash
nano credential_config.sh
```

Fill in the required values:

```bash
# Database Configuration
DB_USER="DB_USER_NAME" #eg:gershon
DB_PASS="YOUR_PASS"
DB_NAME="YOUR_DB_NAME"  # eg:gitea
DB_HOST="YOUR_HOST" #eg:localhost

# Gitea Configuration
GITEA_DATA_DIR="YOUR_GITEA_REPOS"  # eg :/var/lib/gitea


# AWS S3 Configuration
AWS_ACCESS_KEY_ID="YOUR_AWS_ACCESS_KEY_ID"
AWS_SECRET_ACCESS_KEY="YOUR_AWS_SECRET_ACCESS_KEY"
AWS_DEFAULT_REGION="YOUR_REGION" #eg:ap-south-1
S3_BUCKET="YOUR_S3_BUCKET_NAME"
S3_PATH="" #its not ness
```

> 💡 You can leave S3 variables empty if you're only backing up locally.

### 4️⃣ Make Scripts Executable

```bash
chmod +x gitea_to_s3.sh
```

### 5️⃣ Run the Script

```bash
./gitea_to_s3.sh
```

This will:

* ✅ Dump all Gitea repositories
* ✅ Save/compress them to a timestamped archive
* ✅ Push to S3 (if configured)

---

## 🗂️ Output Structure

Backups will be saved in the format:

```
/your/backup/folder/
├── gitea_repos_YYYYMMDD_HHMMSS.tar.gz
└── database_backup.sql
```

---

##

---

##

---

##
