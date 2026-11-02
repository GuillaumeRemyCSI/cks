# Translations shared by the Google Cloud modules: AWS-style lab settings -> GCE equivalents.
variable "name_parts" {
  type = list(string)
}
variable "tags" {
  type    = map(string)
  default = {}
}

locals {
  # Same vCPU / memory as the AWS instance types used by the labs; GCE types pass through.
  machine_types = {
    "t3.micro"   = "e2-micro"
    "t3.small"   = "e2-small"
    "t3.medium"  = "e2-medium"
    "t3.large"   = "e2-standard-2"
    "t3.xlarge"  = "e2-standard-4"
    "t4g.micro"  = "e2-micro"
    "t4g.small"  = "e2-small"
    "t4g.medium" = "e2-medium"
  }
  image_families = {
    "20.04" = "ubuntu-2004-lts"
    "22.04" = "ubuntu-2204-lts"
    "24.04" = "ubuntu-2404-lts-amd64"
  }
}

# Instance names start with "cks-": the work PCs of labs 103/105 match nodes with "Host cks-*".
output "name" {
  value = substr(trim(lower(replace(join("-", concat(["cks"], var.name_parts)), "/[^a-zA-Z0-9-]/", "-")), "-"), 0, 50)
}

# GCP labels: lowercase letters, digits, '_' and '-' only.
output "labels" {
  value = {
    for key, value in var.tags :
    lower(replace(key, "/[^a-zA-Z0-9_-]/", "_")) => substr(lower(replace(value, "/[^a-zA-Z0-9_-]/", "-")), 0, 63)
  }
}

output "machine_types" {
  value = local.machine_types
}

output "image_families" {
  value = local.image_families
}
