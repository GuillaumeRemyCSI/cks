# Root configuration for the Google Cloud variant of the labs (CKS_CLOUD=gcp).
# The stacks are copied under this directory, so find_in_parent_folders() picks this file
# instead of terraform/environments/terragrunt.hcl (AWS).
locals {
  project      = get_env("CKS_GCP_PROJECT")
  region       = get_env("CKS_GCP_REGION", "europe-west1")
  zone         = get_env("CKS_GCP_ZONE", "europe-west1-b")
  state_bucket = get_env("CKS_GCP_STATE_BUCKET")
}

generate "provider" {
  path      = "provider_gcp.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  backend "gcs" {}
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.20.0"
    }
  }
}

provider "google" {
  project = "${local.project}"
  region  = "${local.region}"
  zone    = "${local.zone}"
}
EOF
}

remote_state {
  backend = "gcs"
  config = {
    bucket   = local.state_bucket
    prefix   = "terragrunt${path_relative_to_include()}"
    project  = local.project
    location = local.region
  }
}
