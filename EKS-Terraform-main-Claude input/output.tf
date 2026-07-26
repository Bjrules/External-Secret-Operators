output "cluster_id" {
  value = aws_eks_cluster.bnj.id
}

output "node_group_id" {
  value = aws_eks_node_group.bnj.id
}

output "vpc_id" {
  value = aws_vpc.bnj_vpc.id
}

output "subnet_ids" {
  value = aws_subnet.bnj_subnet[*].id
}
