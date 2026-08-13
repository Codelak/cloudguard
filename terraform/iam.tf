# SEEDED FINDING for Chain A, Project 1 (Automated Least-Privilege and
# Workload Identity Federation): the Lambda execution role below is
# attached to the AWS-managed AmazonS3FullAccess policy, even though
# the function it belongs to (lambda/process_upload) only ever reads
# and writes objects in one specific bucket. This is one of the most
# common real-world IAM mistakes, reaching for a broad managed policy
# because it is easier than writing a scoped one, left here
# deliberately so Project 1 has a genuine, realistic over-permissioned
# role to right-size using real CloudTrail usage data, not a synthetic
# example. Do not tighten this policy outside that project's own work.

resource "aws_iam_role" "lambda_process_upload" {
  name = "${var.environment_name}-process-upload-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_process_upload_overpermissioned" {
  role       = aws_iam_role.lambda_process_upload.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_process_upload_basic_logs" {
  role       = aws_iam_role.lambda_process_upload.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# A second, deliberately standing-access role representing the kind of
# permanent, broad human access Chain A, Project 2 (Just-in-Time Access)
# should replace with a time-bound request flow. Nobody should actually
# assume this role day to day, it exists to be measured against, and
# eventually replaced by a request-based alternative in that project.
resource "aws_iam_role" "standing_developer_access" {
  name = "${var.environment_name}-standing-developer-access"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          # Requires MFA at minimum, even a deliberately over-broad
          # example role should not skip this baseline control.
          Bool = {
            "aws:MultiFactorAuthPresent" = "true"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "standing_developer_access_policy" {
  role       = aws_iam_role.standing_developer_access.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

data "aws_caller_identity" "current" {}
