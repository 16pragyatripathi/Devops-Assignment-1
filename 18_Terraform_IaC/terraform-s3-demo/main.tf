locals {
  common_tags = {
    Owner       = "Pragya Tripathi"
    RollNo      = "24BCS10032"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Session     = "18"
  }
}

# The bucket itself.
resource "aws_s3_bucket" "pragya_demo" {
  bucket        = var.bucket_name
  force_destroy = true # lets `terraform destroy` empty the bucket first

  tags = merge(local.common_tags, { Name = var.bucket_name })
}

# Since AWS provider v4, settings such as versioning and encryption are
# separate resources that point at the bucket.
resource "aws_s3_bucket_versioning" "pragya_demo" {
  bucket = aws_s3_bucket.pragya_demo.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "pragya_demo" {
  bucket = aws_s3_bucket.pragya_demo.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "pragya_demo" {
  bucket = aws_s3_bucket.pragya_demo.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# A small text object so there is something real inside the bucket.
resource "aws_s3_object" "welcome" {
  bucket       = aws_s3_bucket.pragya_demo.id
  key          = "welcome.txt"
  content_type = "text/plain"
  content      = <<-EOT
    Hello from Terraform!
    Owner: Pragya Tripathi (24BCS10032)
    Environment: ${var.environment}
    Bucket: ${var.bucket_name}
  EOT

  tags = local.common_tags
}
