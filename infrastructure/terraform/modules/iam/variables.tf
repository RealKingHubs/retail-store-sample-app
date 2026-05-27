variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "student_id" {
  description = "Student ID for unique resource naming"
  type        = string
}

variable "assets_bucket_name" {
  description = "Name of the S3 assets bucket"
  type        = string
}