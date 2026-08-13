terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }

  # No remote backend configured on purpose: this environment is meant
  # to be applied from a single learner's machine against their own
  # free-tier AWS account, not shared state across a team. If this
  # environment is ever used as the basis for real multi-account work
  # in later projects, that is the point where remote state actually
  # becomes necessary, not before.
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "cloudguard"
      ManagedBy = "terraform"
    }
  }
}
