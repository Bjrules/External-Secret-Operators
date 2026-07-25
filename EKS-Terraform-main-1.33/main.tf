provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "bnj_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "bnj-vpc"
  }
}

resource "aws_subnet" "bnj_subnet" {
  count = 2
  vpc_id                  = aws_vpc.bnj_vpc.id
  cidr_block              = cidrsubnet(aws_vpc.bnj_vpc.cidr_block, 8, count.index)
  availability_zone       = element(["us-east-1b", "us-east-1c"], count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "bnj-subnet-${count.index}"
  }
}

resource "aws_internet_gateway" "bnj_igw" {
  vpc_id = aws_vpc.bnj_vpc.id

  tags = {
    Name = "bnj-igw"
  }
}

resource "aws_route_table" "bnj_route_table" {
  vpc_id = aws_vpc.bnj_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.bnj_igw.id
  }

  tags = {
    Name = "bnj-route-table"
  }
}

resource "aws_route_table_association" "bnj_association" {
  count          = 2
  subnet_id      = aws_subnet.bnj_subnet[count.index].id
  route_table_id = aws_route_table.bnj_route_table.id
}

resource "aws_security_group" "bnj_cluster_sg" {
  vpc_id = aws_vpc.bnj_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bnj-cluster-sg"
  }
}

resource "aws_security_group" "bnj_node_sg" {
  vpc_id = aws_vpc.bnj_vpc.id

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
    Name = "bnj-node-sg"
  }
}

resource "aws_eks_cluster" "bnj" {
  name     = "bnj-cluster"
  role_arn = aws_iam_role.bnj_cluster_role.arn

  vpc_config {
    subnet_ids         = aws_subnet.bnj_subnet[*].id
    security_group_ids = [aws_security_group.bnj_cluster_sg.id]
  }
}
############################# With Claude Contribution ############################

data "aws_iam_openid_connect_provider" "eks" {
  url = aws_eks_cluster.bnj.identity[0].oidc[0].issuer
}

data "aws_iam_policy_document" "ebs_csi_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(data.aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(data.aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.eks.arn]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  name               = "ebs-csi-controller-sa-role"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_assume_role.json
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name              = aws_eks_cluster.bnj.name
  addon_name                = "aws-ebs-csi-driver"
  service_account_role_arn  = aws_iam_role.ebs_csi.arn

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    aws_eks_node_group.bnj,
    aws_iam_role_policy_attachment.ebs_csi
  ]
}

############################# End of Claude Contribution#########################
resource "aws_eks_node_group" "bnj" {
  cluster_name    = aws_eks_cluster.bnj.name
  node_group_name = "bnj-node-group"
  node_role_arn   = aws_iam_role.bnj_node_group_role.arn
  subnet_ids      = aws_subnet.bnj_subnet[*].id

  scaling_config {
    desired_size = 3
    max_size     = 3
    min_size     = 3
  }

  instance_types = ["t2.medium"]

  remote_access {
    ec2_ssh_key = var.ssh_key_name
    source_security_group_ids = [aws_security_group.bnj_node_sg.id]
  }
}

resource "aws_iam_role" "bnj_cluster_role" {
  name = "bnj-cluster-role"

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

resource "aws_iam_role_policy_attachment" "bnj_cluster_role_policy" {
  role       = aws_iam_role.bnj_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "bnj_node_group_role" {
  name = "bnj-node-group-role"

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

resource "aws_iam_role_policy_attachment" "bnj_node_group_role_policy" {
  role       = aws_iam_role.bnj_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "bnj_node_group_cni_policy" {
  role       = aws_iam_role.bnj_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "bnj_node_group_registry_policy" {
  role       = aws_iam_role.bnj_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "bnj_node_group_ebs_policy" {
  role       = aws_iam_role.bnj_node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}
