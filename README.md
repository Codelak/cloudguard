# CloudGuard

A small, real AWS environment: one Lambda function, three S3 buckets, a
KMS key, a minimal VPC, and CloudTrail, all defined in Terraform. This
is the single, shared environment for the entire Expadox Portfolio
Cloud Security track, all 9 projects across all 3 chains (Identity and
Access, Posture and Runtime, Automation and Governance) work against
this one environment, the same reasoning that put DevSecOps on one
shared codebase, an attack path, an entitlement graph, and a drift
report only mean something against one real, continuously evolving
environment, not three disconnected ones.

---

## A real, honest limitation, read this before anything else
This Terraform was written and syntax-checked carefully, every file
parses as valid HCL, every resource reference cross-checked by hand
against what's actually declared, but it was **never run through
`terraform validate` or `terraform plan`** against a real AWS account
or a real Terraform installation. The sandbox this was built in has no
network route to `registry.terraform.io` or HashiCorp's release
servers, so neither the `terraform` binary nor the AWS provider plugin
could be installed here.

**Before you do anything else:** run `terraform init` and
`terraform validate` yourself, in your own environment, against your
own free-tier AWS account, and fix anything that surfaces before
`apply`. Treat this the same way you'd treat any other codebase you
didn't write yourself, review it, don't trust it blindly.

---

## What it is
- One Lambda function (`process_upload`) triggered by S3 uploads,
  real, working Python and boto3, not a stub
- Three S3 buckets: the app's real data bucket, a bucket holding a
  deliberately seeded sensitive-data finding, and a bucket for Lambda
  deployment packages
- One KMS key with a deliberately loose key policy
- A minimal VPC with a private subnet, a free S3 gateway endpoint (no
  NAT Gateway anywhere, that's a paid resource this environment
  deliberately avoids), and a security group with a seeded
  overly-broad egress rule
- CloudTrail, multi-region, logging to its own bucket, real data,
  not optional
- An SNS topic, deliberately unwired, Chain C's projects connect real
  automation to it

## Seeded findings, intentional, documented, and load-bearing
Every finding below is commented at its exact location in the Terraform, and should not be "fixed"
outside the project it belongs to.

- **An over-permissioned Lambda execution role**
  (`terraform/iam.tf`, `aws_iam_role.lambda_process_upload`), attached
  to the AWS-managed `AmazonS3FullAccess` policy when the function only
  ever needs `s3:GetObject` and `s3:PutObject` on one bucket. The
  target for Chain A, Project 1
- **A standing-access developer role** (`terraform/iam.tf`,
  `aws_iam_role.standing_developer_access`), permanent broad access
  where a time-bound request flow should exist instead. The target for
  Chain A, Project 2
- **A sensitive-data-shaped object nobody classified**
  (`terraform/dspm-seed-data.tf`), built entirely from industry-standard
  safe test values, Visa's own published test card number, an
  SSA-documented never-issued SSN pattern, and AWS's own published
  example access key, shaped to be found by a classifier, never real or
  functional. The target for Chain B, Project 5
- **An overly broad KMS key policy** (`terraform/kms.tf`), granting
  decrypt access to any principal in the account instead of the
  specific role that needs it. The target for Chain B, Project 6
- **Unrestricted security group egress** (`terraform/vpc.tf`), 0.0.0.0/0
  on all ports, when the function only ever needs the S3 gateway
  endpoint already in the same file. Also the target for Chain B,
  Project 6

---

## Tech stack
Terraform (AWS and archive providers), AWS Lambda, S3, KMS, VPC,
CloudTrail, SNS, Cloud Custodian for policy-as-code. Every AWS resource
here is chosen to stay within the free tier, no NAT Gateway, no
always-on EC2, no interface VPC endpoints (which bill hourly), only the
free S3 gateway endpoint.

## Deploy steps

### 1. Install Terraform and validate first
```bash
# install terraform 1.9+ for your OS, then:
cd terraform
terraform init
terraform validate
```
Do not skip this. See the limitation note above.

### 2. Review the plan before applying
```bash
terraform plan
```
Read it. Confirm it matches what this README describes, one Lambda,
three buckets, one KMS key, one VPC, one CloudTrail trail, one SNS
topic. If it doesn't, stop and find out why before applying.

### 3. Apply
```bash
terraform apply
```

### 4. Test the upload flow
```bash
BUCKET=$(terraform output -raw uploads_bucket_name)
echo '{"test": true}' > /tmp/sample.json
aws s3 cp /tmp/sample.json "s3://${BUCKET}/incoming/sample.json"
# Check for the metadata object the Lambda function should have written:
aws s3 ls "s3://${BUCKET}/metadata/"
```

### 5. Run the baseline Cloud Custodian policies
```bash
pip install c7n
custodian run -s output custodian/baseline-policies.yml
```

### 6. Tear down completely when done
```bash
terraform destroy
```

---

## What each chain pulls from this environment
- **Chain A, Identity and Access (Projects 1-3):** the over-permissioned
  Lambda role, the standing developer role, and CloudTrail's real usage
  data
- **Chain B, Posture and Runtime (Projects 4-6):** the environment's
  overall configuration for CSPM and drift work, the seeded DSPM
  finding, and the KMS and network findings
- **Chain C, Automation and Governance (Projects 7-9):** the SNS topic,
  the Lambda function as a target for event-driven remediation, and the
  whole environment as the subject of governance baseline and
  compliance work

## Total cost to deploy and run this
Effectively zero if torn down promptly after use, this fits well within
AWS's free tier (Lambda, S3, CloudTrail management events, SNS all have
free tiers that comfortably cover this scale). The one thing to
actually watch is leaving it running indefinitely, `terraform destroy`
when a session ends.
