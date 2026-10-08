# Bucket for build artifacts / database backups of the project
resource "aws_s3_bucket" "artifacts" {
  bucket        = "${var.project}-artifacts-24bcs10032"
  force_destroy = true # lab only: lets terraform destroy remove a non-empty bucket
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket                  = aws_s3_bucket.artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
