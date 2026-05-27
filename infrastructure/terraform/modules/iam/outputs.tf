output "dev_user_name" {
  description = "IAM username for the developer"
  value       = aws_iam_user.dev_view.name
}

output "dev_user_arn" {
  description = "IAM user ARN"
  value       = aws_iam_user.dev_view.arn
}

output "dev_access_key_id" {
  description = "Access key ID for bedrock-dev-view"
  value       = aws_iam_access_key.dev_view.id
}

output "dev_secret_access_key" {
  description = "Secret access key for bedrock-dev-view"
  value       = aws_iam_access_key.dev_view.secret
  sensitive   = true
}

output "dev_console_password" {
  description = "Console login password for bedrock-dev-view"
  value       = aws_iam_user_login_profile.dev_view.password
  sensitive   = true
}

output "dev_credentials_secret_arn" {
  description = "ARN of the secret storing all dev credentials"
  value       = aws_secretsmanager_secret.dev_view_password.arn
}