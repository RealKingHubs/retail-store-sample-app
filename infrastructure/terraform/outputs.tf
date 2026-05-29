output "cluster_endpoint" {
  description = "EKS cluster API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "region" {
  description = "AWS region"
  value       = var.aws_region
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "assets_bucket_name" {
  description = "S3 bucket name for asset uploads"
  value       = module.s3_lambda.bucket_name
}

output "cart_role_arn" {
  description = "IAM role ARN for cart service DynamoDB access"
  value       = aws_iam_role.cart.arn
}

output "app_url" {
  description = "URL of the retail store application"
  value       = length(kubernetes_ingress_v1.retail_app.status[0].load_balancer[0].ingress) > 0 ? "http://${kubernetes_ingress_v1.retail_app.status[0].load_balancer[0].ingress[0].hostname}" : "ALB still provisioning - run terraform output app_url after a few minutes"
}