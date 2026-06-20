#!/usr/bin/env bash
# End-to-end interactive S3FS Mount script for Ubuntu EC2 instances.
# Saved at /home/ubuntu/s3-mount/cloud-machine-setup/s3_mount_setup.sh

set -e

# Visual styling
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================================${NC}"
echo -e "${BLUE}       AWS S3 INTERACTIVE MOUNT SETUP TOOL            ${NC}"
echo -e "${BLUE}======================================================${NC}"

# Check for root / sudo access
if [ "$EUID" -ne 0 ]; then
  echo -e "${YELLOW}Notice: Some tasks (like installing packages) will require sudo access.${NC}"
fi

# Step 1: System Package Update & Dependency Installation
echo -e "\n${BLUE}[1/5] Checking and installing system dependencies...${NC}"
sudo apt-get update -y

dependencies=(unzip wget curl s3fs)
missing_deps=()

for dep in "${dependencies[@]}"; do
  if ! command -v "$dep" &> /dev/null; then
    missing_deps+=("$dep")
  fi
done

if [ ${#missing_deps[@]} -gt 0 ]; then
  echo -e "Installing missing dependencies: ${missing_deps[*]}"
  sudo apt-get install -y "${missing_deps[@]}"
else
  echo -e "${GREEN}All base dependencies (unzip, wget, curl, s3fs) are already installed.${NC}"
fi

# Step 2: Install AWS CLI if not present
if ! command -v aws &> /dev/null; then
  echo -e "AWS CLI not found. Downloading and installing..."
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
  unzip -q /tmp/awscliv2.zip -d /tmp/
  sudo /tmp/aws/install
  rm -rf /tmp/awscliv2.zip /tmp/aws
  echo -e "${GREEN}AWS CLI version $(aws --version) successfully installed.${NC}"
else
  echo -e "${GREEN}AWS CLI is already installed: $(aws --version)${NC}"
fi

# Step 3: Interactive IAM Permissions Setup & Verification
echo -e "\n${BLUE}[2/5] Setting up AWS IAM Permissions${NC}"
echo -e "${YELLOW}IMPORTANT: An IAM Role (Instance Profile) must be attached to this EC2 instance.${NC}"
echo -e "To create and attach it:"
echo -e " 1. Go to AWS Console -> IAM -> Roles -> Create Role."
echo -e " 2. Select 'AWS Service' and choose 'EC2'."
echo -e " 3. Attach 'AmazonS3FullAccess' policy (or a custom read-write policy for your bucket)."
echo -e " 4. Go to EC2 Console -> Select this instance -> Actions -> Security -> Modify IAM Role."
echo -e " 5. Select the role you created and click Update."

while true; do
  read -rp "Has the IAM Role been attached to this instance? (y/n): " iam_attached
  if [[ "$iam_attached" =~ ^[Yy]$ ]]; then
    break
  else
    echo -e "${YELLOW}Please attach the IAM Role in the AWS Console before continuing.${NC}"
  fi
done

# Verify connection loop
while true; do
  read -rp "Enter the name of your S3 Bucket (e.g. agentic-paper-s3): " BUCKET_NAME
  
  echo -e "Testing S3 connectivity using: ${BLUE}aws s3 ls s3://$BUCKET_NAME${NC} ..."
  if aws s3 ls "s3://$BUCKET_NAME" > /dev/null 2>&1; then
    echo -e "${GREEN}Success! Verified access to bucket: s3://$BUCKET_NAME${NC}"
    break
  else
    echo -e "${RED}Access Denied or Bucket Not Found.${NC}"
    echo -e "Common causes:"
    echo -e " - The bucket name '$BUCKET_NAME' is misspelled."
    echo -e " - The attached IAM role policy is missing permission for s3:ListBucket on this bucket."
    echo -e " - The IAM role update has not propagated yet (usually takes ~10 seconds)."
    echo ""
    read -rp "Press Enter to try verifying again, or type 'change' to enter a different bucket name: " verify_choice
    if [ "$verify_choice" = "change" ]; then
      continue
    fi
  fi
done

# Step 4: Configure FUSE settings for shared access
echo -e "\n${BLUE}[3/5] Configuring FUSE permissions & caching${NC}"
read -rp "Do you want other users/docker containers to access this mount? (recommended) (y/n): " allow_other
IF_ALLOW_OTHER=""
if [[ "$allow_other" =~ ^[Yy]$ ]]; then
  echo "Enabling user_allow_other in /etc/fuse.conf..."
  sudo sed -i 's/#user_allow_other/user_allow_other/' /etc/fuse.conf
  IF_ALLOW_OTHER=",allow_other"
fi

# Step 5: Configure Mount Point & Mount the Bucket
echo -e "\n${BLUE}[4/5] Mounting S3 Bucket with Cache${NC}"
while true; do
  read -rp "Enter the directory path to mount to (default: ~/s3-mount): " MOUNT_PATH
  MOUNT_PATH="${MOUNT_PATH:-~/s3-mount}"
  
  # Expand tilde ~ to full home path
  eval MOUNT_PATH="$MOUNT_PATH"
  
  mkdir -p "$MOUNT_PATH"
  
  # Check if directory is already mounted
  if mountpoint -q "$MOUNT_PATH"; then
    echo -e "${YELLOW}Warning: Directory $MOUNT_PATH is already mounted. Attempting to unmount first...${NC}"
    fusermount -u "$MOUNT_PATH" || sudo umount "$MOUNT_PATH" || true
  fi

  echo -e "Mounting s3://$BUCKET_NAME to $MOUNT_PATH (using local cache /tmp)..."
  if s3fs "$BUCKET_NAME" "$MOUNT_PATH" -o "iam_role=auto,use_cache=/tmp${IF_ALLOW_OTHER}"; then
    # Give it a second to settle and verify
    sleep 2
    if mountpoint -q "$MOUNT_PATH"; then
      echo -e "${GREEN}Success! Mounted S3 bucket successfully.${NC}"
      break
    else
      echo -e "${RED}Mount command succeeded but directory is not recognized as a mount point.${NC}"
    fi
  else
    echo -e "${RED}Failed to mount S3 bucket using s3fs.${NC}"
  fi
  
  read -rp "Do you want to retry mounting to a different path? (y/n): " retry_mount
  if [[ ! "$retry_mount" =~ ^[Yy]$ ]]; then
    exit 1
  fi
done

# Step 6: Final Verification and Show Files
echo -e "\n${BLUE}[5/5] Verifying mounted files...${NC}"
echo -e "Files in S3 Mount directory ($MOUNT_PATH):"
echo -e "------------------------------------------------"
ls -la "$MOUNT_PATH"
echo -e "------------------------------------------------"

echo -e "\n${GREEN}Mount Setup Completed successfully!${NC}"
echo -e "Your S3 bucket ${BLUE}s3://$BUCKET_NAME${NC} is now attached to ${BLUE}$MOUNT_PATH${NC}."
echo -e "Local cache is enabled at: ${BLUE}/tmp/.${BUCKET_NAME}.mirror${NC}"
echo -e "You can now read, write, and execute files directly in this directory."
echo -e "To unmount at any time, run: ${YELLOW}fusermount -u $MOUNT_PATH${NC}"
echo -e "${BLUE}======================================================${NC}"
