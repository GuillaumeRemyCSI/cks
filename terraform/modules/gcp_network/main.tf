# Google Cloud counterpart of vpc_v2: same inputs and outputs, so the lab stacks only switch
# the module source. Subnets are regional on GCP: the "az" of each subnet is ignored.
variable "prefix" {}
variable "app_name" {}
variable "vpc_default_cidr" {}
variable "USER_ID" {
  type    = string
  default = "defaultUser"
}
variable "ENV_ID" {
  type    = string
  default = "defaultId"
}
variable "subnets" {
  type = object({
    public = map(object({
      name = string
      cidr = string
      az   = optional(string)
    }))
    private = optional(map(object({
      name = string
      cidr = string
      az   = optional(string)
    })), {})
  })
}

locals {
  USER_ID = var.USER_ID == "" ? "defaultUser" : var.USER_ID
  ENV_ID  = var.ENV_ID == "" ? "defaultId" : var.ENV_ID
  # GCP names: lowercase letters, digits and '-', 63 characters max.
  name    = substr(trim(lower(replace("cks-${local.USER_ID}-${local.ENV_ID}-${var.prefix}", "/[^a-zA-Z0-9-]/", "-")), "-"), 0, 50)
  subnets = merge(var.subnets.public, var.subnets.private)
}

resource "google_compute_network" "vpc" {
  name                    = local.name
  auto_create_subnetworks = false
  # GCP defaults to 1460: the CNI manifests of the labs expect a standard 1500 MTU.
  mtu = 1500
}

resource "google_compute_subnetwork" "subnet" {
  for_each = local.subnets

  name          = substr("${local.name}-${lower(replace(each.key, "/[^a-zA-Z0-9-]/", "-"))}", 0, 63)
  network       = google_compute_network.vpc.id
  ip_cidr_range = each.value.cidr
}

# Kubernetes (API, kubelet, CNI encapsulation) needs every protocol between the VMs of the lab.
resource "google_compute_firewall" "internal" {
  name          = "${local.name}-internal"
  network       = google_compute_network.vpc.id
  source_ranges = [var.vpc_default_cidr]

  allow {
    protocol = "all"
  }
}

output "vpc_id" {
  value = google_compute_network.vpc.id
}

# Same order as vpc_v2 (sorted keys of the public subnets): subnet_number "0" is the first one.
output "subnets" {
  value = [for key in sort(keys(var.subnets.public)) : google_compute_subnetwork.subnet[key].id]
}

output "vpc_default_cidr" {
  value = var.vpc_default_cidr
}
