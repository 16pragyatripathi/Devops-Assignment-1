variable "aws_region" {
  description = "AWS region where the bucket is created."
  type        = string
  default     = "ap-south-1"
}

variable "localstack_endpoint" {
  description = "URL of the LocalStack edge port (ignored once the endpoints block is removed for real AWS)."
  type        = string
  default     = "http://localhost:4566"
}

variable "bucket_name" {
  description = "Name of the S3 bucket. On real AWS this must be unique across every account in the world."
  type        = string
  default     = "pragya-24bcs10032-tf-demo"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "Bucket name must be 3-63 characters of lowercase letters, digits, dots or hyphens."
  }
}

variable "environment" {
  description = "Environment name used in tags and in the welcome object."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "test", "staging", "prod"], var.environment)
    error_message = "environment must be dev, test, staging or prod."
  }
}

variable "project_name" {
  description = "Project tag."
  type        = string
  default     = "pragya-terraform-training"
}

variable "enable_versioning" {
  description = "Turn on S3 object versioning."
  type        = bool
  default     = true
}
