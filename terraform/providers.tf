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

  # Remote state, added by Chain A, Project 1, Phase 4.
  #
  # The comment that used to sit here said no remote backend was
  # configured on purpose, because the environment was meant to be
  # applied from a single learner's machine, and that remote state would
  # "become necessary" only if the environment were used for real
  # multi-account work in later projects. Phase 4 is that point.
  #
  # Eliminating the static deployment credential means the deploy has to
  # run from GitHub Actions, and a CI runner starts with no state at
  # all — it would try to create 33 resources that already exist and
  # fail on every name collision. Remote state is what lets CI read the
  # same record of the environment that the learner's machine reads.
  #
  # The bucket and lock table are bootstrapped outside Terraform, which
  # is unavoidable rather than sloppy: the backend must exist before
  # `terraform init` can be told to use it. See the walkthrough, 4.1.
  backend "s3" {
    bucket         = "cloudguard-tfstate-851725187277"
    key            = "cloudguard/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "cloudguard-tfstate-lock"
    encrypt        = true
  }
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
