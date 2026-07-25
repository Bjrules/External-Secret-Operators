output "cluster_id" {
  value = aws_eks_cluster.bj.id
}

output "node_group_id" {
  value = aws_eks_node_group.bj.id
}

output "vpc_id" {
  value = aws_vpc.bj_vpc.id
}

output "subnet_ids" {
  value = aws_subnet.bj_subnet[*].id
}
