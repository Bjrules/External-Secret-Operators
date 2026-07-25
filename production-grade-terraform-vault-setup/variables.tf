variable "cluster_name" {
  description = "Name of the existing EKS cluster"
  type        = string
  default     = "bj-cluster"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vault_namespace" {
  description = "Kubernetes namespace where Vault is deployed"
  type        = string
  default     = "vault"
}

variable "vault_service_account_name" {
  description = "ServiceAccount name used by Vault server pods (matches the Helm chart's default)"
  type        = string
  default     = "vault"
}

variable "kms_key_deletion_window" {
  description = "Number of days before a deleted KMS key is permanently removed"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default = {
    ManagedBy = "terraform"
    Purpose   = "vault-auto-unseal"
  }
}
