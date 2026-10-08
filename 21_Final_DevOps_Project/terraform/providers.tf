# By default this runs against LocalStack (the ls-pragya container on :4566),
# so I can apply/destroy for free. Set use_localstack=false to use real AWS
# credentials from `aws configure` / environment variables instead.
provider "aws" {
  region = var.aws_region

  access_key                  = var.use_localstack ? "test" : null # LocalStack dummy value, not a secret
  secret_key                  = var.use_localstack ? "test" : null
  skip_credentials_validation = var.use_localstack
  skip_metadata_api_check     = var.use_localstack
  skip_requesting_account_id  = var.use_localstack
  s3_use_path_style           = var.use_localstack

  endpoints {
    ec2 = var.use_localstack ? var.localstack_endpoint : null
    s3  = var.use_localstack ? var.localstack_endpoint : null
    sts = var.use_localstack ? var.localstack_endpoint : null
    iam = var.use_localstack ? var.localstack_endpoint : null
    eks = var.use_localstack ? var.localstack_endpoint : null
  }

  default_tags {
    tags = {
      Project   = var.project
      Owner     = "Pragya Tripathi"
      RollNo    = "24BCS10032"
      Session   = "21"
      ManagedBy = "Terraform"
    }
  }
}
