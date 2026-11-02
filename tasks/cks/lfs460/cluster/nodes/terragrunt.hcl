include {
  path = find_in_parent_folders()
}

locals {
  vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "../../..//modules/${local.vars.locals.cloud == "gcp" ? "gcp_lfs460_nodes" : "lfs460_nodes"}/"
}

dependency "vpc" {
  config_path = "../vpc"
}

inputs = {
  region         = local.vars.locals.region
  prefix         = local.vars.locals.prefix
  tags_common    = local.vars.locals.tags
  vpc_id         = dependency.vpc.outputs.vpc_id
  subnets        = dependency.vpc.outputs.subnets
  nodes          = local.vars.locals.nodes
  instance_type  = local.vars.locals.instance_type
  ubuntu_version = local.vars.locals.ubuntu_version
  access_cidrs   = local.vars.locals.access_cidrs
}
