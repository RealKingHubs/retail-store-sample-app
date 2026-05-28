#!/bin/bash
# Exit immediately if a command exits with a non-zero status
set -e

# Variables
BUCKET_NAME="project-bedrock-tfstate-alt-soe-025-3658"
REGION="us-east-1"

echo "Creating S3 bucket: ${BUCKET_NAME}..."
aws s3api create-bucket \
  --bucket "$BUCKET_NAME" \
  --region "$REGION"

echo "Enabling bucket versioning..."
aws s3api put-bucket-versioning \
  --bucket "$BUCKET_NAME" \
  --versioning-configuration Status=Enabled

echo "Applying public access block configuration..."
aws s3api put-public-access-block \
  --bucket "$BUCKET_NAME" \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

echo "Setup complete! Bucket is secured and ready for Terraform state."


