data "aws_caller_identity" "current" {}

# IAM user for the developer
resource "aws_iam_user" "dev_view" {
  name = "bedrock-dev-view"
  path = "/"

  tags = {
    Name = "bedrock-dev-view"
  }
}

# Console login profile with a generated password
resource "aws_iam_user_login_profile" "dev_view" {
  user                    = aws_iam_user.dev_view.name
  password_reset_required = false
}

# Access keys for programmatic access (kubectl and S3 upload)
resource "aws_iam_access_key" "dev_view" {
  user = aws_iam_user.dev_view.name
}

# Attach AWS managed ReadOnlyAccess policy
resource "aws_iam_user_policy_attachment" "read_only" {
  user       = aws_iam_user.dev_view.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# Custom policy granting s3:PutObject on the assets bucket only
resource "aws_iam_policy" "s3_put_object" {
  name        = "bedrock-dev-s3-put-policy"
  description = "Allow bedrock-dev-view to upload files to the assets bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "s3:PutObject"
        Resource = "arn:aws:s3:::${var.assets_bucket_name}/*"
      }
    ]
  })

  tags = {
    Name = "bedrock-dev-s3-put-policy"
  }
}

resource "aws_iam_user_policy_attachment" "s3_put_object" {
  user       = aws_iam_user.dev_view.name
  policy_arn = aws_iam_policy.s3_put_object.arn
}

# Store the console password in Secrets Manager for safe retrieval
resource "aws_secretsmanager_secret" "dev_view_password" {
  name                    = "${var.cluster_name}/bedrock-dev-view-credentials"
  recovery_window_in_days = 0

  tags = {
    Name = "bedrock-dev-view-credentials"
  }
}

resource "aws_secretsmanager_secret_version" "dev_view_password" {
  secret_id = aws_secretsmanager_secret.dev_view_password.id
  secret_string = jsonencode({
    username         = aws_iam_user.dev_view.name
    password         = aws_iam_user_login_profile.dev_view.password
    access_key_id     = aws_iam_access_key.dev_view.id
    secret_access_key = aws_iam_access_key.dev_view.secret
    console_url       = "https://${data.aws_caller_identity.current.account_id}.signin.aws.amazon.com/console"
  })
}