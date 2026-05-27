output "cart_table_name" {
  description = "DynamoDB cart table name"
  value       = aws_dynamodb_table.cart.name
}

output "cart_table_arn" {
  description = "DynamoDB cart table ARN"
  value       = aws_dynamodb_table.cart.arn
}