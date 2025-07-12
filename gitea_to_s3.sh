#!/bin/bash
set -eo pipefail

# configuration file
CONFIG_FILE="${1:-./credential_config.sh}"


# --------------------------
# Load Configuration
# --------------------------

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "❌ Critical Error: Configuration file '$CONFIG_FILE' not found" >&2
    exit 1
fi

source "$CONFIG_FILE"

# --------------------------
# Validate Configuration
# --------------------------

declare -a REQUIRED_VARS=("DB_USER" "DB_PASS" "DB_NAME" "AWS_ACCESS_KEY_ID" "AWS_SECRET_ACCESS_KEY" "S3_BUCKET")
for var in "${REQUIRED_VARS[@]}"; do
    if [[ -z "${!var}" ]]; then
        echo "❌ Critical Error: $var is not set in configuration file" >&2
        exit 1
    fi
done

# Set defaults for optional variables
DB_HOST="${DB_HOST:-localhost}"
REPO_DIR="${REPO_DIR:-/var/lib/gitea/data/gitea-repositories}"
AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
S3_PATH="${S3_PATH:-gitea-backups}"

# --------------------------
# Initialize Backup Variables
# --------------------------

REPO_DIR="$GITEA_DATA_DIR/data/gitea-repositories"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="gitea_backup_${TIMESTAMP}.zip"
TMP_DIR=$(mktemp -d -t gitea_backup_XXXXXX)
LOG_FILE="/data/ops_scripts/gitea_backup/backup.log"

echo "TEMP directory will be created at : $TMP_DIR"

# Function to cleanup on exit
cleanup() {
    local exit_code=$?
    if [[ -d "$TMP_DIR" ]]; then
        rm -rf "$TMP_DIR"
    fi
    exit $exit_code
}
trap cleanup EXIT

# --------------------------
# Logging Setup
# --------------------------
exec > >(tee -a "$LOG_FILE") 2>&1
echo "[$(date)] Starting Gitea Backup Process"
echo "Configuration:"
echo "  - Database User: $DB_USER"
echo "  - Database Name: $DB_NAME"
echo "  - Database Host: $DB_HOST"
echo "  - Repository Directory: $REPO_DIR"
echo "AWS S3 Configuration:"
echo "  - S3 Bucket: $S3_BUCKET"
echo "  - S3 Path: $S3_PATH"
echo "  - AWS Region: $AWS_DEFAULT_REGION"

# --------------------------
# Pre-flight Checks
# --------------------------
echo "🔍 Running pre-flight checks..."

# Check if running as appropriate user
if [[ $EUID -ne 0 ]] && [[ ! -w "$TMP_DIR" ]]; then
    echo "⚠️  Warning: May need elevated privileges for temporary directory"
fi

# Check required directories exist
if [[ ! -d "$REPO_DIR" ]]; then
    echo "❌ Repository directory not found: $REPO_DIR" >&2
    exit 1
fi

# Check database connectivity
if ! mysql -u "$DB_USER" -p"$DB_PASS" -h "$DB_HOST" -e "USE $DB_NAME;" &>/dev/null; then
    echo "❌ Database connection failed" >&2
    echo "   Troubleshooting steps:" >&2
    echo "   1. Verify credentials in $CONFIG_FILE" >&2
    echo "   2. Check MySQL service: systemctl status mysql" >&2
    echo "   3. Verify user privileges: SHOW GRANTS FOR '$DB_USER'@'$DB_HOST'" >&2
    exit 2
fi

# Check AWS CLI is installed
if ! command -v aws &>/dev/null; then
    echo "❌ AWS CLI is not installed" >&2
    echo "   Install with: sudo apt install awscli (Debian/Ubuntu) or sudo yum install awscli (RHEL/CentOS)" >&2
    exit 3
fi

# --------------------------
# Modified AWS Credential Check
# --------------------------
echo "🔐 Verifying AWS credentials with explicit auth..."
if ! AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
   AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
   AWS_DEFAULT_REGION="$AWS_DEFAULT_REGION" \
   aws sts get-caller-identity &>/dev/null; then
    echo "❌ AWS credentials verification failed" >&2
    echo "   Verify:" >&2
    echo "   1. AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY in $CONFIG_FILE" >&2
    echo "   2. No typos in credentials (compare with 'aws configure get aws_access_key_id')" >&2
    echo "   3. AWS_DEFAULT_REGION matches your bucket's region" >&2
    exit 4
fi

# Check S3 bucket exists and is accessible
if ! AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
   AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
   AWS_DEFAULT_REGION="$AWS_DEFAULT_REGION" \
   aws s3 ls "s3://$S3_BUCKET" &>/dev/null; then
    echo "❌ Cannot access S3 bucket: $S3_BUCKET" >&2
    echo "   Verify:" >&2
    echo "   1. Bucket exists in $AWS_DEFAULT_REGION" >&2
    echo "   2. IAM user has s3:ListBucket permission" >&2
    exit 5
fi

# --------------------------
# Backup Repositories
# --------------------------
echo "📦 Backing up repositories from $REPO_DIR..."
if ! rsync -a --delete --info=progress2 "$REPO_DIR/" "$TMP_DIR/repositories/"; then
    echo "❌ Repository backup failed" >&2
    exit 6
fi

# --------------------------
# Backup Database
# --------------------------
echo "🛢️ Backing up database '$DB_NAME'..."
MYSQL_PWD="$DB_PASS" mysqldump \
    --single-transaction \
    --routines \
    --triggers \
    --no-tablespaces \
    --add-drop-table \
    --disable-keys \
    --extended-insert \
    -u "$DB_USER" \
    -h "$DB_HOST" \
    "$DB_NAME" > "$TMP_DIR/gitea.sql"

if [[ $? -ne 0 ]]; then
    echo "❌ Database backup failed" >&2
    exit 7
fi

# --------------------------
# Create Archive
# --------------------------
echo "🗜️ Creating backup archive..."
if ! (cd "$TMP_DIR" && zip -qr -9 "$TMP_DIR/$BACKUP_NAME" .); then
    echo "❌ Archive creation failed" >&2
    exit 8
fi

# --------------------------
# Verify Backup
# --------------------------
echo "✅ Verifying backup integrity..."
if ! zip -T "$TMP_DIR/$BACKUP_NAME" &>/dev/null; then
    echo "❌ Backup archive is corrupted" >&2
    exit 9
fi

# --------------------------
# Upload to S3 (Modified)
# --------------------------
echo "☁️ Uploading backup to S3..."
S3_FULL_PATH="s3://$S3_BUCKET/$BACKUP_NAME"

if ! AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
   AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
   AWS_DEFAULT_REGION="$AWS_DEFAULT_REGION" \
   aws s3 cp "$TMP_DIR/$BACKUP_NAME" "$S3_FULL_PATH"; then
    echo "❌ Failed to upload backup to S3" >&2
    exit 10
fi

# --------------------------
# Finalize Backup
# --------------------------
BACKUP_SIZE=$(du -h "$TMP_DIR/$BACKUP_NAME" | cut -f1)
echo "✅ Backup completed and uploaded successfully!"
echo "   ☁️  S3 Location: $S3_FULL_PATH"
echo "   📊 Size: $BACKUP_SIZE"
echo "   📝 Log: $LOG_FILE"
echo "   📦 Contents: Git repositories + MySQL database"

echo "[$(date)] Backup process completed successfully"
exit 0
 
