resource "aws_s3_bucket" "assets" {
  bucket        = var.assets_bucket_name
  force_destroy = true

  tags = { Name = var.assets_bucket_name }
}

resource "aws_s3_bucket_versioning" "assets" {
  bucket = aws_s3_bucket.assets.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "assets" {
  bucket = aws_s3_bucket.assets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# A JSON file built from IDs that only exist after the network and compute
# resources are created - so Terraform must create this object last.
resource "aws_s3_object" "inventory" {
  bucket       = aws_s3_bucket.assets.id
  key          = "inventory.json"
  content_type = "application/json"
  content = jsonencode({
    owner           = "Pragya Tripathi (24BCS10032)"
    vpc_id          = aws_vpc.main.id
    public_subnets  = aws_subnet.public[*].id
    private_subnets = aws_subnet.private[*].id
    web_instances   = zipmap(aws_instance.web[*].id, aws_instance.web[*].private_ip)
    app_instance    = { (aws_instance.app.id) = aws_instance.app.private_ip }
  })
}
