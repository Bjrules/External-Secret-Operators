output "region" {
  description = "AWS region"
  value       = var.region
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_arn" {
  description = "Cluster ARN"
  value       = module.eks.cluster_arn
}

output "cluster_endpoint" {
  description = "API endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Cluster SG"
  value       = module.eks.cluster_security_group_id
}

output "node_security_group_id" {
  description = "Node SG"
  value       = module.eks.node_security_group_id
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnets
}

output "kubeconfig_cmd" {
  description = "Command to set kubeconfig"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.region}"
}