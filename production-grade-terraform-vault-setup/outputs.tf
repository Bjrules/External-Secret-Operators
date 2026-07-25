output "kms_key_id" {
  description = "KMS key ID to use in Vault's seal \"awskms\" config block (kms_key_id)"
  value       = aws_kms_key.vault_unseal.key_id
}

output "kms_key_arn" {
  description = "Full ARN of the Vault unseal KMS key"
  value       = aws_kms_key.vault_unseal.arn
}

output "vault_iam_role_arn" {
  description = "IAM Role ARN to annotate Vault's ServiceAccount with (eks.amazonaws.com/role-arn)"
  value       = aws_iam_role.vault_kms_unseal.arn
}
