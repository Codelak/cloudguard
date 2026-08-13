variable "aws_region" {
  description = "AWS region to deploy CloudGuard into. Pick a region with free-tier Lambda and S3 available."
  type        = string
  default     = "us-east-1"
}

variable "environment_name" {
  description = "Short name used as a prefix on every resource, keeps this environment identifiable and easy to tear down completely."
  type        = string
  default     = "cloudguard"
}

variable "alert_email" {
  description = "Email address for the SNS topic that Chain C's automated response and compliance projects publish to. Leave blank to skip subscribing an email at apply time."
  type        = string
  default     = ""
}
