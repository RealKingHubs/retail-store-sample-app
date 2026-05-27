#!/bin/bash
set -e

echo "Fetching RDS endpoints from Terraform outputs..."

cd infrastructure/terraform

MYSQL_ENDPOINT=$(terraform output -raw cluster_endpoint 2>/dev/null || echo "")

# Get RDS endpoints directly from AWS
MYSQL_ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier project-bedrock-cluster-mysql \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text \
  --region us-east-1)

POSTGRES_ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier project-bedrock-cluster-postgres \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text \
  --region us-east-1)

echo "MySQL endpoint: $MYSQL_ENDPOINT"
echo "Postgres endpoint: $POSTGRES_ENDPOINT"

cd ../../

# Update catalog configmap
sed -i "s|MYSQL_ENDPOINT_PLACEHOLDER|$MYSQL_ENDPOINT|g" \
  infrastructure/k8s/retail-app/catalog.yaml

# Update orders configmap
sed -i "s|POSTGRES_ENDPOINT_PLACEHOLDER|$POSTGRES_ENDPOINT|g" \
  infrastructure/k8s/retail-app/orders.yaml

echo "Kubernetes configs updated with RDS endpoints successfully."