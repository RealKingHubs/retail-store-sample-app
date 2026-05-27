module "vpc" {
  source = "./modules/vpc"

  vpc_name     = var.vpc_name
  aws_region   = var.aws_region
  cluster_name = var.cluster_name
}

module "eks" {
  source = "./modules/eks"

  cluster_name       = var.cluster_name
  aws_region         = var.aws_region
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids
  node_instance_type = var.node_instance_type
  node_desired_size  = var.node_desired_size
  node_min_size      = var.node_min_size
  node_max_size      = var.node_max_size
  app_namespace      = var.app_namespace
}

module "rds" {
  source = "./modules/rds"

  cluster_name           = var.cluster_name
  vpc_id                 = module.vpc.vpc_id
  private_subnet_ids     = module.vpc.private_subnet_ids
  node_security_group_id = module.eks.node_security_group_id
  db_username            = var.db_username
  db_password            = var.db_password
}

module "dynamodb" {
  source = "./modules/dynamodb"

  cluster_name = var.cluster_name
}

module "iam" {
  source = "./modules/iam"

  cluster_name       = var.cluster_name
  student_id         = var.student_id
  assets_bucket_name = "bedrock-assets-${var.student_id}"
}

module "s3_lambda" {
  source = "./modules/s3-lambda"

  student_id   = var.student_id
  cluster_name = var.cluster_name
}

resource "kubernetes_namespace_v1" "retail_app" {
  metadata {
    name = var.app_namespace
    labels = {
      name = var.app_namespace
    }
  }

  depends_on = [module.eks]
}

resource "helm_release" "alb_controller" {
  name             = "aws-load-balancer-controller"
  repository       = "https://aws.github.io/eks-charts"
  chart            = "aws-load-balancer-controller"
  namespace        = "kube-system"
  version          = "1.11.0"
  force_update     = true
  cleanup_on_fail  = true
  recreate_pods    = true

  values = [
    yamlencode({
      clusterName = var.cluster_name
      vpcId       = module.vpc.vpc_id
      region      = var.aws_region
      serviceAccount = {
        create = true
        name   = "aws-load-balancer-controller"
        annotations = {
          "eks.amazonaws.com/role-arn" = module.eks.alb_controller_role_arn
        }
      }
    })
  ]

  depends_on = [
    module.eks,
    kubernetes_namespace_v1.retail_app
  ]
}

# Read MySQL credentials from Secrets Manager and create Kubernetes secret
resource "kubernetes_secret_v1" "mysql_credentials" {
  metadata {
    name      = "catalog-db"
    namespace = var.app_namespace
  }

  data = {
    RETAIL_CATALOG_PERSISTENCE_USER     = var.db_username
    RETAIL_CATALOG_PERSISTENCE_PASSWORD = var.db_password
  }

  depends_on = [
    kubernetes_namespace_v1.retail_app,
    module.rds
  ]
}

# Read PostgreSQL credentials from Secrets Manager and create Kubernetes secret
resource "kubernetes_secret_v1" "postgres_credentials" {
  metadata {
    name      = "orders-db"
    namespace = var.app_namespace
  }

  data = {
    RETAIL_ORDERS_PERSISTENCE_USER     = var.db_username
    RETAIL_ORDERS_PERSISTENCE_PASSWORD = var.db_password
  }

  depends_on = [
    kubernetes_namespace_v1.retail_app,
    module.rds
  ]
}

resource "kubernetes_secret_v1" "rabbitmq_credentials" {
  metadata {
    name      = "orders-rabbitmq"
    namespace = var.app_namespace
  }

  data = {
    RETAIL_ORDERS_MESSAGING_RABBITMQ_USERNAME = "guest"
    RETAIL_ORDERS_MESSAGING_RABBITMQ_PASSWORD = "guest"
  }

  depends_on = [kubernetes_namespace_v1.retail_app]
}

# IAM role for cart service to access DynamoDB (IRSA)
data "aws_iam_policy_document" "cart_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${var.app_namespace}:cart-service-account"]
    }
  }
}

resource "aws_iam_role" "cart" {
  name               = "${var.cluster_name}-cart-role"
  assume_role_policy = data.aws_iam_policy_document.cart_assume.json

  tags = {
    Name = "${var.cluster_name}-cart-role"
  }
}

resource "aws_iam_policy" "cart_dynamodb" {
  name        = "${var.cluster_name}-cart-dynamodb-policy"
  description = "Allow cart service to access DynamoDB"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = module.dynamodb.cart_table_arn
      }
    ]
  })

  tags = {
    Name = "${var.cluster_name}-cart-dynamodb-policy"
  }
}

resource "aws_iam_role_policy_attachment" "cart_dynamodb" {
  role       = aws_iam_role.cart.name
  policy_arn = aws_iam_policy.cart_dynamodb.arn
}

# Update the cart service account with the correct IAM role ARN
resource "kubernetes_service_account_v1" "cart" {
  metadata {
    name      = "cart-service-account"
    namespace = var.app_namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.cart.arn
    }
  }

  depends_on = [
    kubernetes_namespace_v1.retail_app,
    aws_iam_role_policy_attachment.cart_dynamodb
  ]
}

# Map bedrock-dev-view IAM user to Kubernetes view ClusterRole
resource "kubernetes_cluster_role_binding_v1" "dev_view" {
  metadata {
    name = "bedrock-dev-view-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "view"
  }

  subject {
    kind      = "User"
    name      = "bedrock-dev-view"
    api_group = "rbac.authorization.k8s.io"
  }

  depends_on = [module.eks]
}

# Create EKS access entry and associate view policy for bedrock-dev-view IAM user
resource "aws_eks_access_entry" "dev_view" {
  cluster_name  = var.cluster_name
  principal_arn = module.iam.dev_user_arn
  type          = "STANDARD"

  depends_on = [module.eks]
}

resource "aws_eks_access_policy_association" "dev_view" {
  cluster_name  = var.cluster_name
  principal_arn = module.iam.dev_user_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.dev_view]
}


# Grant the cluster creator admin access to the cluster
resource "aws_eks_access_entry" "admin" {
  cluster_name  = var.cluster_name
  principal_arn = "arn:aws:iam::093796422475:user/Start-Tech"
  type          = "STANDARD"

  depends_on = [module.eks]
}

resource "aws_eks_access_policy_association" "admin" {
  cluster_name  = var.cluster_name
  principal_arn = "arn:aws:iam::093796422475:user/Start-Tech"
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.admin]
}