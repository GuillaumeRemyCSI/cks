locals {
  # Cloud the lab runs on: "aws" (default) or "gcp" (see training/README.md).
  cloud = get_env("CKS_CLOUD", "aws")

  region           = "eu-central-1"
  vpc_default_cidr = "10.47.0.0/16"
  aws              = "default"
  prefix           = "lfs460-cluster"

  tags = {
    "env_name"        = "lfs460-cluster"
    "env_type"        = "training"
    "manage"          = "terraform"
    "cost_allocation" = "training"
  }

  nodes          = ["cp", "worker"]
  instance_type  = "t3.large"
  ubuntu_version = "24.04"
  access_cidrs   = split(",", get_env("CKS_ACCESS_CIDRS", "0.0.0.0/0"))

  subnets = {
    public = {
      "pub1" = {
        name = "lfs460"
        cidr = "10.47.1.0/24"
        az   = "eu-central-1a"
      }
    }
    private = {}
  }
}
