#!/bin/bash

# Variables
BUCKET_NAME="project-bedrock-tfstate-alt-soe-025-3658"

# Check if bucket exists first
if ! aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo "Bucket ${BUCKET_NAME} does not exist or you do not have access."
    exit 0
fi

echo "Warning: This will permanently delete all versions and data in ${BUCKET_NAME}."
read -p "Are you sure you want to proceed? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo "Cleanup cancelled."
    exit 1
fi

echo "Removing all object versions..."
aws s3api delete-objects \
  --bucket "$BUCKET_NAME" \
  --delete "$(aws s3api list-object-versions --bucket "$BUCKET_NAME" --output json --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}')" 2>/dev/null

echo "Removing all delete markers..."
aws s3api delete-objects \
  --bucket "$BUCKET_NAME" \
  --delete "$(aws s3api list-object-versions --bucket "$BUCKET_NAME" --output json --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}')" 2>/dev/null

echo "Deleting the empty bucket..."
aws s3api delete-bucket --bucket "$BUCKET_NAME"

echo "Cleanup complete! Bucket ${BUCKET_NAME} has been removed."
