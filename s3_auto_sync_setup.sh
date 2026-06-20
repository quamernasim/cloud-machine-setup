#!/usr/bin/env bash
# Automatic S3 background sync setup script.
# Saved at /home/ubuntu/s3-mount/cloud-machine-setup/s3_auto_sync_setup.sh

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}======================================================${NC}"
echo -e "${BLUE}     S3 BACKGROUND AUTOMATIC SYNC INSTALLER           ${NC}"
echo -e "${BLUE}======================================================${NC}"

# Check for AWS CLI
if ! command -v aws &> /dev/null; then
  echo -e "${RED}Error: AWS CLI is not installed. Please run s3_mount_setup.sh first to install it.${NC}"
  exit 1
fi

# Step 1: Get Local Directory
read -rp "Enter the local directory to watch/sync (default: /home/ubuntu/geophysical-multi-model-agentic-ai): " LOCAL_DIR
LOCAL_DIR="${LOCAL_DIR:-/home/ubuntu/geophysical-multi-model-agentic-ai}"
eval LOCAL_DIR="$LOCAL_DIR"

if [ ! -d "$LOCAL_DIR" ]; then
  echo -e "${RED}Error: Local directory $LOCAL_DIR does not exist.${NC}"
  exit 1
fi

# Step 2: Get S3 Bucket & Prefix
read -rp "Enter the S3 Bucket Name (default: agentic-paper-s3): " BUCKET_NAME
BUCKET_NAME="${BUCKET_NAME:-agentic-paper-s3}"

read -rp "Enter the S3 Destination Prefix/Folder (default: geophysical-multi-model-agentic-ai): " S3_PREFIX
S3_PREFIX="${S3_PREFIX:-geophysical-multi-model-agentic-ai}"

S3_PATH="s3://$BUCKET_NAME/$S3_PREFIX"

# Step 3: Verify Access
echo -e "\nVerifying S3 connectivity to $S3_PATH ..."
if aws s3 ls "s3://$BUCKET_NAME" > /dev/null 2>&1; then
  echo -e "${GREEN}Success! S3 permissions verified.${NC}"
else
  echo -e "${RED}Access Denied or Bucket Not Found. Please attach the correct IAM role or check bucket name.${NC}"
  exit 1
fi

# Step 4: Configure the Cron Job
echo -e "\nConfiguring background cron job (runs every minute)..."

# Construct the cron command line to sync everything
CRON_CMD="* * * * * aws s3 sync $LOCAL_DIR $S3_PATH >/dev/null 2>&1"

# Read existing crontab
CURRENT_CRON=$(crontab -l 2>/dev/null || echo "")

# Prevent duplicate cron jobs
if echo "$CURRENT_CRON" | grep -Fq "aws s3 sync $LOCAL_DIR"; then
  echo -e "${YELLOW}An automatic sync cron job for this directory is already registered. Updating it...${NC}"
  # Remove the old one
  CURRENT_CRON=$(echo "$CURRENT_CRON" | grep -Fv "aws s3 sync $LOCAL_DIR")
fi

# Write the new crontab
NEW_CRON=$(echo -e "${CURRENT_CRON}\n${CRON_CMD}" | sed '/^$/d')
echo "$NEW_CRON" | crontab -

echo -e "\n${GREEN}======================================================${NC}"
echo -e "${GREEN} Background Auto-Sync setup complete!${NC}"
echo -e " Local directory: ${BLUE}$LOCAL_DIR${NC}"
echo -e " S3 destination:  ${BLUE}$S3_PATH${NC}"
echo -e " Interval:        ${YELLOW}Every minute (silent in background)${NC}"
echo -e "${GREEN}======================================================${NC}"
