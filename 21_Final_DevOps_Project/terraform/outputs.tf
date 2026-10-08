output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "artifacts_bucket" {
  value = aws_s3_bucket.artifacts.bucket
}

output "eks_cluster_name" {
  value = var.create_eks ? aws_eks_cluster.main[0].name : "(not created - create_eks = false)"
}

output "kubeconfig_command" {
  value = var.create_eks ? "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.main[0].name}" : "n/a"
}
