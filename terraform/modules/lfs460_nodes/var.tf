variable "region" {}
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

# Hostnames of the nodes, as used in the LFS460 exercises (single, cp, worker).
variable "nodes" {
  type = list(string)
}
variable "instance_type" {
  type    = string
  default = "t3.large" # 2 vCPU / 8 GiB, the size the course asks for
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
