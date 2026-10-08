output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.main.cidr_block
}

output "public_subnets" {
  description = "Public subnet IDs mapped to CIDR and AZ."
  value       = { for s in aws_subnet.public : s.id => "${s.cidr_block} ${s.availability_zone}" }
}

output "private_subnets" {
  description = "Private subnet IDs mapped to CIDR and AZ."
  value       = { for s in aws_subnet.private : s.id => "${s.cidr_block} ${s.availability_zone}" }
}

output "security_groups" {
  description = "Security group IDs."
  value = {
    web = aws_security_group.web.id
    app = aws_security_group.app.id
  }
}

output "web_instances" {
  description = "Web server instance ID -> private IP."
  value       = zipmap(aws_instance.web[*].id, aws_instance.web[*].private_ip)
}

output "app_instance_private_ip" {
  description = "Private IP of the backend instance."
  value       = aws_instance.app.private_ip
}

output "ami_used" {
  description = "AMI chosen by the data source."
  value       = "${data.aws_ami.amazon_linux.id} (${data.aws_ami.amazon_linux.name})"
}

output "assets_bucket" {
  description = "Name of the assets bucket."
  value       = aws_s3_bucket.assets.bucket
}

output "nat_gateway_id" {
  description = "NAT gateway ID, or null when it is disabled."
  value       = one(aws_nat_gateway.main[*].id)
}
