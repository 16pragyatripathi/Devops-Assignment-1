terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Runs against LocalStack (AWS APIs emulated in Docker on my laptop).
# For real AWS delete everything under "LocalStack only" and let the
# provider pick up credentials from `aws configure` / env vars / SSO.
provider "aws" {
  region = var.aws_region

  # Every taggable resource gets these tags automatically.
  default_tags {
    tags = {
      Owner     = "Pragya Tripathi"
      RollNo    = "24BCS10032"
      Project   = var.project
      Session   = "19"
      ManagedBy = "Terraform"
    }
  }

  # ---- LocalStack only ------------------------------------------------------
  access_key                  = "test" # LocalStack dummy key, not a secret
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  endpoints {
    ec2 = var.localstack_endpoint
    s3  = var.localstack_endpoint
    sts = var.localstack_endpoint
    iam = var.localstack_endpoint
  }
}
