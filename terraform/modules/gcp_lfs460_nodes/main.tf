# Google Cloud counterpart of lfs460_nodes: bare Ubuntu nodes for the official LFS460 exercises.
# No service account on purpose: participants have sudo, so there must be no credentials to steal.
variable "prefix" {}
variable "USER_ID" {
  type    = string
  default = "defaultUser"
}
variable "ENV_ID" {
  type    = string
  default = "defaultId"
}
variable "tags_common" {
  type    = map(string)
  default = {}
}
variable "vpc_id" {}
variable "subnets" {
  type = list(string)
}
variable "nodes" {
  type = list(string)
}
variable "instance_type" {
  type    = string
  default = "t3.large"
}
variable "ubuntu_version" {
  type    = string
  default = "24.04"
}
variable "root_volume_size" {
  type    = number
  default = 20
}
variable "access_cidrs" {
  type = list(string)
}

locals {
  USER_ID     = var.USER_ID == "" ? "defaultUser" : var.USER_ID
  ENV_ID      = var.ENV_ID == "" ? "defaultId" : var.ENV_ID
  network_tag = "${module.common.name}-nodes"
}

module "common" {
  source     = "../gcp_common"
  name_parts = [local.USER_ID, local.ENV_ID]
  tags       = var.tags_common
}

data "google_compute_image" "ubuntu" {
  family  = module.common.image_families[var.ubuntu_version]
  project = "ubuntu-os-cloud"
}

# One password per participant, shared by all the nodes of the stack.
resource "random_string" "student" {
  length  = 12
  special = false
}

# Traffic between the nodes is allowed by gcp_network.
resource "google_compute_firewall" "ssh" {
  name          = "${module.common.name}-ssh"
  network       = var.vpc_id
  source_ranges = var.access_cidrs
  target_tags   = [local.network_tag]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_instance" "node" {
  for_each = toset(var.nodes)

  name           = "${module.common.name}-${each.key}"
  machine_type   = lookup(module.common.machine_types, var.instance_type, var.instance_type)
  tags           = [local.network_tag]
  labels         = module.common.labels
  can_ip_forward = true

  boot_disk {
    initialize_params {
      image = data.google_compute_image.ubuntu.self_link
      size  = var.root_volume_size
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = var.subnets[0]
    access_config {}
  }

  metadata = {
    "block-project-ssh-keys" = "true"
    "enable-oslogin"         = "FALSE"
    "user-data" = templatefile("${path.module}/../lfs460_nodes/template/node.sh", {
      hostname = each.key
      password = random_string.student.result
    })
  }

  allow_stopping_for_update = true
  lifecycle {
    ignore_changes = [metadata["user-data"], boot_disk]
  }
}

output "public_ips" {
  value = { for name, node in google_compute_instance.node : name => node.network_interface[0].access_config[0].nat_ip }
}

output "student_password" {
  value     = random_string.student.result
  sensitive = true
}
