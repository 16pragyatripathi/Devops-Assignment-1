# This project runs against LocalStack (AWS APIs emulated in a Docker
# container on my laptop) because I have no real AWS account credentials here.
#
# Everything below the "LocalStack only" comment must be removed for real AWS.
# Real credentials then come from `aws configure`, environment variables or
# SSO - never from this file.
provider "aws" {
  region = var.aws_region

  # ---- LocalStack only ------------------------------------------------------
  # "test"/"test" are the fixed dummy keys LocalStack accepts. They are not
  # secrets and do not work against real AWS.
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  endpoints {
    s3  = var.localstack_endpoint
    sts = var.localstack_endpoint
    iam = var.localstack_endpoint
  }
}
