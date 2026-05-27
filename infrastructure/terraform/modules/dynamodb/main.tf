resource "aws_dynamodb_table" "cart" {
  name         = "retailstore-cart"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Name = "${var.cluster_name}-cart-table"
  }
}