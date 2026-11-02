locals {
  # Cloud the lab runs on: "aws" (default) or "gcp" (see training/README.md).
  cloud = get_env("CKS_CLOUD", "aws")

  # Repository the lab VMs download their bootstrap scripts and tests from.
  # Override with CKS_REPO=<owner>/<repo> and CKS_REPO_REF=<branch> to use a fork.
  repo     = get_env("CKS_REPO", "ViktorUJ/cks")
  repo_ref = get_env("CKS_REPO_REF", "master")
  raw_base = "https://raw.githubusercontent.com/${local.repo}/${local.repo_ref}"

  questions_list    = "https://github.com/${local.repo}/blob/${local.repo_ref}/tasks/cks/labs/101/README_FR.MD"
  solutions_scripts = "https://github.com/${local.repo}/blob/${local.repo_ref}/tasks/cks/labs/101/worker/files/solutions/1_FR.MD"
  solutions_video   = "Not ready yet"
  debug_output      = "false"
  region            = "eu-central-1"
  vpc_default_cidr  = "10.101.0.0/16"
  aws               = "default"
  prefix            = "cks-task101"

  tags = {
    "env_name"        = "cks-task101"
    "env_type"        = "dev"
    "manage"          = "terraform"
    "cost_allocation" = "dev"
    "owner"           = "viktoruj@gmail.com"
  }

  k8_version = "1.35.2"
  node_type  = "ondemand"
  runtime    = "containerd"
  cni = {
    type               = "calico"
    disable_kube_proxy = "false"
  }

  instance_type         = "t3.medium"
  instance_type_worker  = "t3.small"
  spot_additional_types = ["t3.medium"]
  all_spot_subnet       = "true"
  key_name              = ""
  ssh_password_enable   = "true"
  access_cidrs          = split(",", get_env("CKS_ACCESS_CIDRS", "0.0.0.0/0"))
  ubuntu_version        = "24.04"
  ami_id                = ""

  root_volume = {
    type = "gp3"
    size = "10"
  }

  subnets = {
    public = {
      "pub1" = {
        name = "k8s-1"
        cidr = "10.101.1.0/24"
        az   = "eu-central-1a"
      }
      "pub2" = {
        name = "k8s-2"
        cidr = "10.101.2.0/24"
        az   = "eu-central-1b"
      }
    }
    private = {}
  }
}
