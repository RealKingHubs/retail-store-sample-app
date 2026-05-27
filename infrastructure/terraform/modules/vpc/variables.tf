variable "vpc_name" {
  description = "Name tag for the VPC"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name, used for subnet tags"
  type        = string
}