# SEEDED FINDING for Chain B, Project 6 (Attack Path Analysis and
# Network and Encryption Hardening): the key policy below grants
# kms:Decrypt and kms:GenerateDataKey to ANY principal in this AWS
# account, not scoped to the specific roles that actually need to use
# it (lambda_process_upload). This is one of the most common real KMS
# mistakes: relying on IAM alone and leaving the key policy itself wide
# open, when the key policy is the resource-side control that should
# also be scoped. Left exactly this way on purpose, do not tighten it
# outside that project's own work.
resource "aws_kms_key" "uploads_encryption" {
  description             = "Encrypts objects in the uploads bucket"
  deletion_window_in_days = 7

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootAccountAdmin"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "OverlyBroadDecryptGrant"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
        # No Condition block scoping this to specific roles, this is
        # the actual seeded gap: any principal that can assume any
        # role in the account can decrypt with this key.
      }
    ]
  })
}

resource "aws_kms_alias" "uploads_encryption" {
  name          = "alias/${var.environment_name}-uploads"
  target_key_id = aws_kms_key.uploads_encryption.key_id
}
