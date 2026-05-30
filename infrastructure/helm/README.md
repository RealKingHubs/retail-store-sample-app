# Helm-Based Application Deployment

All retail store microservices are deployed using their upstream Helm charts with custom values overriding the data layer to point at managed AWS services (RDS, DynamoDB) instead of in-cluster databases.

## Prerequisites

- kubectl configured for the EKS cluster
- Helm 3.x installed
- AWS credentials configured

## Services and Charts

| Service | Chart Location | Backend |
|---------|---------------|---------|
| Catalog | src/catalog/chart | RDS MySQL |
| Cart | src/cart/chart | DynamoDB |
| Orders | src/orders/chart | RDS PostgreSQL |
| Checkout | src/checkout/chart | Redis (in-cluster) |
| UI | src/ui/chart | - |

## Deploy All Services

All services are managed through Terraform which calls the Helm charts automatically. To deploy manually, use the following commands:

### Catalog Service
```bash
helm upgrade --install catalog src/catalog/chart \
  --namespace retail-app \
  --create-namespace \
  --set image.tag=1.2.1 \
  --set app.persistence.provider=mysql \
  --set app.persistence.endpoint=<RDS_MYSQL_ENDPOINT>:3306 \
  --set app.persistence.database=catalog \
  --set app.persistence.secret.create=false \
  --set app.persistence.secret.name=catalog-db \
  --set mysql.create=false
```

### Cart Service
```bash
helm upgrade --install cart src/cart/chart \
  --namespace retail-app \
  --set image.tag=1.2.1 \
  --set app.persistence.provider=dynamodb \
  --set app.persistence.dynamodb.tableName=retailstore-cart \
  --set serviceAccount.create=false \
  --set serviceAccount.name=cart-service-account \
  --set dynamodb.create=false
```

### Orders Service
```bash
helm upgrade --install orders src/orders/chart \
  --namespace retail-app \
  --set image.tag=1.2.1 \
  --set app.persistence.provider=postgres \
  --set app.persistence.endpoint=<RDS_POSTGRES_ENDPOINT>:5432 \
  --set app.persistence.database=orders \
  --set app.persistence.secret.create=false \
  --set app.persistence.secret.name=orders-db \
  --set app.messaging.provider=rabbitmq \
  --set app.messaging.rabbitmq.addresses=orders-rabbitmq:5672 \
  --set app.messaging.rabbitmq.secret.create=false \
  --set app.messaging.rabbitmq.secret.name=orders-rabbitmq \
  --set postgresql.create=false \
  --set rabbitmq.create=true
```

### Checkout Service
```bash
helm upgrade --install checkout src/checkout/chart \
  --namespace retail-app \
  --set image.tag=1.2.1 \
  --set app.persistence.provider=redis \
  --set app.endpoints.orders=http://orders \
  --set redis.create=true
```

### UI Service
```bash
helm upgrade --install ui src/ui/chart \
  --namespace retail-app \
  --set image.tag=1.2.1 \
  --set app.endpoints.catalog=http://catalog \
  --set app.endpoints.carts=http://cart-carts \
  --set app.endpoints.checkout=http://checkout \
  --set app.endpoints.orders=http://orders
```

## Preferred Method

The recommended deployment method is via Terraform which manages all Helm releases as code:

```bash
cd infrastructure/terraform
terraform init
terraform apply -auto-approve
```

This ensures all infrastructure and application deployments are managed in a single state file.