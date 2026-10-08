variable "project" {
  description = "Name prefix for every resource"
  type        = string
  default     = "pragya-library"
}

variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "use_localstack" {
  description = "true = talk to LocalStack on localhost:4566 instead of real AWS"
  type        = bool
  default     = true
}

variable "localstack_endpoint" {
  type    = string
  default = "http://localhost:4566"
}

variable "vpc_cidr" {
  type    = string
  default = "10.21.0.0/16"
}

variable "public_subnet_cidrs" {
  type    = list(string)
  default = ["10.21.1.0/24", "10.21.2.0/24"]
}

variable "private_subnet_cidrs" {
  type    = list(string)
  default = ["10.21.101.0/24", "10.21.102.0/24"]
}

variable "create_nat_gateway" {
  description = "Private subnets reach the internet through one NAT gateway (costs money on real AWS)"
  type        = bool
  default     = true
}

variable "create_eks" {
  description = "Create the EKS control plane + node group. EKS is not in LocalStack Community, so it is false for apply and true only for plan."
  type        = bool
  default     = false
}

variable "kubernetes_version" {
  type    = string
  default = "1.33"
}

variable "node_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "node_desired_size" {
  type    = number
  default = 2
}
