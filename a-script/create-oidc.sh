GITHUB_ORG="RealKingHubs"
GITHUB_REPO="retail-store-sample-app"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)


#create the GitHub OIDC provider
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1

#create the IAM role for GitHub Actions
aws iam create-role \
  --role-name github-actions-bedrock-role \
  --assume-role-policy-document "{
    \"Version\": \"2012-10-17\",
    \"Statement\": [
      {
        \"Effect\": \"Allow\",
        \"Principal\": {
          \"Federated\": \"arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com\"
        },
        \"Action\": \"sts:AssumeRoleWithWebIdentity\",
        \"Condition\": {
          \"StringLike\": {
            \"token.actions.githubusercontent.com:sub\": \"repo:${GITHUB_ORG}/${GITHUB_REPO}:*\"
          },
          \"StringEquals\": {
            \"token.actions.githubusercontent.com:aud\": \"sts.amazonaws.com\"
          }
        }
      }
    ]
  }"

aws iam attach-role-policy \
  --role-name github-actions-bedrock-role \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

echo "Role ARN: arn:aws:iam::${ACCOUNT_ID}:role/github-actions-bedrock-role"