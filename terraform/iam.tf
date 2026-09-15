# SEEDED FINDING, NOW CLOSED by Chain A, Project 1 (Automated
# Least-Privilege and Workload Identity Federation), 2026-09-15. This role
# was attached to the AWS-managed AmazonS3FullAccess policy, granting
# s3:* on Resource "*" to a function that reads and writes objects in one
# bucket. That grant was the subject of the project, not an accident, and
# the scoped replacement below is where the project's work landed.
#
# The replacement is not a guess about what the function needs. Phase 2
# enabled CloudTrail S3 data events and read back what this role actually
# did across five recorded invocations: s3:GetObject and s3:PutObject,
# nothing else, on one bucket. SOP-Generation/Project-1-Walkthrough.md
# section 2.6 has the query that produced that evidence.

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

# The right-sized policy. Two actions, both derived from observed usage:
#
#   s3:GetObject on the bucket covers reading whatever object triggered the
#   function. The reads are scoped to the bucket rather than to the
#   incoming/ prefix deliberately, because the function reads whatever key
#   the event names and the prefix is already enforced by the notification
#   filter in lambda.tf. Duplicating that constraint here would couple this
#   policy to a setting that lives somewhere else. (Phase 3 narrows it
#   further on purpose, to prove the scope is real. See the walkthrough.)
#
#   s3:PutObject is scoped to metadata/* because that is a genuine property
#   of the code, not a setting that could move: the function writes its
#   output under that prefix and nowhere else, and no configuration in this
#   environment could cause it to write anywhere else.
data "aws_iam_policy_document" "lambda_process_upload_scoped" {
  statement {
    sid    = "ReadUploadedObjects"
    effect = "Allow"

    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.uploads.arn}/*"]
  }

  # Under-scoping test, performed 2026-09-15 and recorded in section 3.4 of
  # the walkthrough. This statement was temporarily removed to prove it is
  # load-bearing: with it gone the function still read its input object and
  # was then refused on the write with
  #
  #   AccessDenied ... not authorized to perform: s3:PutObject ...
  #   because no identity-based policy allows the s3:PutObject action
  #
  # which is the evidence that this policy, and nothing else, governs the
  # function's S3 access. Do not remove it again outside that test.
  statement {
    sid    = "WriteMetadataObjects"
    effect = "Allow"

    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.uploads.arn}/metadata/*"]
  }
}

resource "aws_iam_policy" "lambda_process_upload_scoped" {
  name        = "${var.environment_name}-process-upload-s3-scoped"
  description = "Least-privilege S3 access for process_upload, scoped from CloudTrail data events."

  policy = data.aws_iam_policy_document.lambda_process_upload_scoped.json
}

resource "aws_iam_role_policy_attachment" "lambda_process_upload_scoped" {
  role       = aws_iam_role.lambda_process_upload.name
  policy_arn = aws_iam_policy.lambda_process_upload_scoped.arn
}

resource "aws_iam_role_policy_attachment" "lambda_process_upload_basic_logs" {
  role       = aws_iam_role.lambda_process_upload.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# A VPC-attached Lambda needs permission to create and manage the elastic
# network interfaces it runs on. Without this, CreateFunction is rejected
# outright with "The provided execution role does not have permissions to
# call CreateNetworkInterface on EC2". Kept as a separate attachment from
# the S3 policies above on purpose: this permission exists because of where
# the function runs, not what it does, and Project 1's right-sizing work
# targets the S3 attachment only.
resource "aws_iam_role_policy_attachment" "lambda_process_upload_vpc_access" {
  role       = aws_iam_role.lambda_process_upload.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
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
