variable "aws_region" {
  description = "AWS region for the whole environment."
  type        = string
  default     = "ap-south-1"
}

variable "localstack_endpoint" {
  description = "LocalStack edge URL (only used by the LocalStack endpoints block)."
  type        = string
  default     = "http://localhost:4566"
}

variable "project" {
  description = "Prefix used in every Name tag."
  type        = string
  default     = "pragya-s19"
}

variable "vpc_cidr" {
  description = "Address range of the VPC."
  type        = string
  default     = "10.20.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid IPv4 CIDR, for example 10.20.0.0/16."
  }
}

variable "azs" {
  description = "Two availability zones. One public and one private subnet is created in each."
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b"]

  validation {
    condition     = length(var.azs) == 2
    error_message = "This design expects exactly two availability zones."
  }
}

variable "instance_type" {
  description = "EC2 instance size."
  type        = string
  default     = "t3.micro"
}

variable "ssh_allowed_cidr" {
  description = "Only this range may SSH to the web servers. Put your own public IP /32 here, never 0.0.0.0/0."
  type        = string
  default     = "203.0.113.25/32"
}

variable "enable_nat_gateway" {
  description = "Create a NAT gateway so private instances can reach the internet. Costs money on real AWS, so it is off by default."
  type        = bool
  default     = false
}

variable "assets_bucket_name" {
  description = "Name of the S3 bucket for static assets. Must be globally unique on real AWS."
  type        = string
  default     = "pragya-24bcs10032-s19-assets"
}
