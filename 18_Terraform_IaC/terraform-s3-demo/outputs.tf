output "bucket_name" {
  description = "Name of the S3 bucket."
  value       = aws_s3_bucket.pragya_demo.bucket
}

output "bucket_arn" {
  description = "ARN of the S3 bucket."
  value       = aws_s3_bucket.pragya_demo.arn
}

output "bucket_region" {
  description = "Region the bucket was created in."
  value       = aws_s3_bucket.pragya_demo.region
}

output "versioning_status" {
  description = "Versioning state of the bucket."
  value       = aws_s3_bucket_versioning.pragya_demo.versioning_configuration[0].status
}

output "welcome_object" {
  description = "S3 URI of the uploaded object."
  value       = "s3://${aws_s3_bucket.pragya_demo.bucket}/${aws_s3_object.welcome.key}"
}
