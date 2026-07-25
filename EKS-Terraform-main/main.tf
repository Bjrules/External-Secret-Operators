provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "bj_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "bj-vpc"
  }
}

resource "aws_subnet" "bj_subnet" {
  count = 2
  vpc_id                  = aws_vpc.bj_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.bj_vpc.cidr_block, 8, count.index)
  availability_zone       = element(["us-east-1b", "us-east-1c"], count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "bj-subnet-${count.index}"
  }
}

resource "aws_internet_gateway" "bj_igw" {
  vpc_id = aws_vpc.bj_vpc.id

  tags = {
    Name = "bj-igw"
  }
}

resource "aws_route_table" "bj_route_table" {
  vpc_id = aws_vpc.bj_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.bj_igw.id
  }

  tags = {
    Name = "bj-route-table"
  }
}

resource "aws_route_table_association" "bj_association" {
  count          = 2
  subnet_id      = aws_subnet.bj_subnet[count.index].id
  route_table_id = aws_route_table.bj_route_table.id
}

resource "aws_security_group" "bj_cluster_sg" {
  vpc_id = aws_vpc.bj_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bj-cluster-sg"
  }
}

resource "aws_security_group" "bj_node_sg" {
  vpc_id = aws_vpc.bj_vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bj-node-sg"
  }
}

resource "aws_eks_cluster" "bj" {
  name     = "bj-cluster"
  role_arn = aws_iam_role.bj_cluster_role.arn

  vpc_config {
    subnet_ids         = aws_subnet.bj_subnet[*].id
    security_group_ids = [aws_security_group.bj_cluster_sg.id]
  }
}


resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name    = aws_eks_cluster.bj.name
  addon_name      = "aws-ebs-csi-driver"
  
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}


resource "aws_eks_node_group" "bj" {
  cluster_name    = aws_eks_cluster.bj.name
  node_group_name = "bj-node-group"
  node_role_arn   = aws_iam_role.bj_node_group_role.arn
  subnet_ids      = aws_subnet.bj_subnet[*].id

  scaling_config {
    desired_size = 3
    max_size     = 3
    min_size     = 3
  }

  instance_types = ["t2.medium"]

  remote_access {
    ec2_ssh_key = var.ssh_key_name
    source_security_group_ids = [aws_security_group.bj_node_sg.id]
  }
}

resource "aws_iam_role" "bj_cluster_role" {
  name = "bj-cluster-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "bj_cluster_role_policy" {
  role       = aws_iam_role.bj_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "bj_node_group_role" {
  name = "bj-node-group-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "bj_node_group_role_policy" {
  role       = aws_iam_role.bj_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "bj_node_group_cni_policy" {
  role       = aws_iam_role.bj_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "bj_node_group_registry_policy" {
  role       = aws_iam_role.bj_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "bj_node_group_ebs_policy" {
  role       = aws_iam_role.bj_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}
