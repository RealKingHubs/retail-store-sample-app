#!/bin/bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ROLE_NAME="github-actions-bedrock-role"
OIDC_ARN="arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"

echo "Starting complete IAM cleanup..."

# 1. Detach the AdministratorAccess policy from the role
echo "Detaching AdministratorAccess policy from $ROLE_NAME..."
aws iam detach-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess 2>/dev/null

if [ $? -eq 0 ]; then
  echo "✔ Successfully detached policy."
else
  echo "⚠ Policy was not attached or role does not exist."
fi

# 2. Delete the IAM role
echo "Deleting IAM role: $ROLE_NAME..."
aws iam delete-role --role-name "$ROLE_NAME" 2>/dev/null

if [ $? -eq 0 ]; then
  echo "✔ Successfully deleted IAM role."
else
  echo "⚠ Failed to delete role or it does not exist."
fi

# 3. Delete the OpenID Connect Provider
echo "Deleting OIDC Provider: $OIDC_ARN..."
aws iam delete-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_ARN" 2>/dev/null

if [ $? -eq 0 ]; then
  echo "✔ Successfully deleted OIDC Provider."
else
  echo "⚠ Failed to delete OIDC provider or it does not exist."
fi

echo "Cleanup complete! All resources removed."
