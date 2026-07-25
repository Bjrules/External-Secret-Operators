##############################################
# Data sources - existing EKS cluster + OIDC
##############################################

data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

data "aws_iam_openid_connect_provider" "eks" {
  url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

##############################################
# KMS key dedicated to Vault auto-unseal
# Do NOT reuse this key for other purposes -
# keep the blast radius of Vault's unseal key
# isolated from unrelated workloads.
##############################################

resource "aws_kms_key" "vault_unseal" {
  description             = "KMS key for Vault auto-unseal (${var.cluster_name})"
  deletion_window_in_days = var.kms_key_deletion_window
  enable_key_rotation     = true

  tags = var.tags
}

resource "aws_kms_alias" "vault_unseal" {
  name          = "alias/vault-unseal-${var.cluster_name}"
  target_key_id = aws_kms_key.vault_unseal.key_id
}

##############################################
# IAM Role (IRSA) for the Vault ServiceAccount
# Grants only the KMS permissions Vault needs
# to encrypt/decrypt its unseal key material.
##############################################

data "aws_iam_policy_document" "vault_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(data.aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:${var.vault_namespace}:${var.vault_service_account_name}"]
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

resource "aws_iam_role" "vault_kms_unseal" {
  name               = "vault-kms-unseal-role"
  assume_role_policy = data.aws_iam_policy_document.vault_assume_role.json
  tags               = var.tags
}

data "aws_iam_policy_document" "vault_kms_permissions" {
  statement {
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:DescribeKey",
    ]
    resources = [aws_kms_key.vault_unseal.arn]
  }
}

resource "aws_iam_policy" "vault_kms_unseal" {
  name   = "vault-kms-unseal-policy"
  policy = data.aws_iam_policy_document.vault_kms_permissions.json
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "vault_kms_unseal" {
  role       = aws_iam_role.vault_kms_unseal.name
  policy_arn = aws_iam_policy.vault_kms_unseal.arn
}

##############################################
# Kubernetes ServiceAccount annotation
#
# NOTE: The Vault Helm chart creates its own
# ServiceAccount by default (server.serviceAccount.create=true).
# Rather than fighting the chart for ownership of that
# resource, the recommended approach is to let Helm create
# it, then patch the annotation via Helm values (see the
# eksAnnotations block in values-vault-production.yaml),
# OR set server.serviceAccount.create=false and manage it
# here instead. Both options shown below - pick one.
##############################################

# Option A (used if server.serviceAccount.create=false in Helm values):
resource "kubernetes_service_account" "vault" {
  count = 0 # flip to 1 if managing the SA via Terraform instead of Helm

  metadata {
    name      = var.vault_service_account_name
    namespace = var.vault_namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.vault_kms_unseal.arn
    }
  }
}
