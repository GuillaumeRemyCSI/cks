# Google Cloud counterpart of work_pc_v2: the participant's work PC (kubectl, check_result...),
# bootstrapped by the same scripts (template/, derived from the AWS ones).
# No service account and no extra disks (non_root_volumes is not used by the CKS labs).
locals {
  USER_ID      = var.USER_ID == "" ? "defaultUser" : var.USER_ID
  ENV_ID       = var.ENV_ID == "" ? "defaultId" : var.ENV_ID
  name         = module.common.name
  prefix       = local.name
  network_tag  = "${local.name}-pc"
  spot         = var.work_pc.node_type == "spot"
  machine_type = lookup(module.common.machine_types, var.work_pc.instance_type, var.work_pc.instance_type)

  worker_pc_ip       = google_compute_instance.work_pc.network_interface[0].access_config[0].nat_ip
  worker_pc_ip_local = google_compute_instance.work_pc.network_interface[0].network_ip
  worker_pc_ssh      = var.ssh_password_enable == "true" ? "   ssh ubuntu@${local.worker_pc_ip} password= ${random_string.ssh.result}   " : "   ssh ubuntu@${local.worker_pc_ip}   "
  hosts              = join(" ", var.host_list)
}

module "common" {
  source     = "../gcp_common"
  name_parts = [local.USER_ID, local.ENV_ID, var.prefix, var.app_name]
  tags       = var.tags_common
}

data "google_compute_image" "work_pc" {
  family  = module.common.image_families[var.work_pc.ubuntu_version]
  project = "ubuntu-os-cloud"
}

resource "random_string" "ssh" {
  length  = 10
  special = false
}

# Same openings as the AWS security group: SSH and Prometheus.
resource "google_compute_firewall" "access" {
  name          = "${local.name}-access"
  network       = var.vpc_id
  source_ranges = var.work_pc.cidrs
  target_tags   = [local.network_tag]

  allow {
    protocol = "tcp"
    ports    = ["22", "9090"]
  }
}

resource "google_compute_instance" "work_pc" {
  name         = local.name
  machine_type = local.machine_type
  tags         = [local.network_tag]
  labels       = merge(module.common.labels, { app_name = lower(var.app_name) })

  boot_disk {
    initialize_params {
      image = data.google_compute_image.work_pc.self_link
      size  = var.work_pc.root_volume.size
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = var.subnets[tonumber(var.work_pc.subnet_number)]
    access_config {}
  }

  scheduling {
    provisioning_model          = local.spot ? "SPOT" : "STANDARD"
    preemptible                 = local.spot
    automatic_restart           = !local.spot
    instance_termination_action = local.spot ? "STOP" : null
  }

  metadata = {
    "block-project-ssh-keys" = "true"
    "enable-oslogin"         = "FALSE"
    "user-data" = templatefile("${path.module}/template/boot_zip.sh", {
      boot_zip = base64gzip(templatefile("${path.module}/${var.work_pc.user_data_template}", {
        clusters_config     = join(" ", [for key, value in var.work_pc.clusters_config : "${key}=${value}"])
        kubectl_version     = var.work_pc.util.kubectl_version
        ssh_private_key     = var.work_pc.ssh.private_key
        ssh_pub_key         = var.work_pc.ssh.pub_key
        exam_time_minutes   = var.work_pc.exam_time_minutes
        test_url            = var.work_pc.test_url
        task_script_url     = var.work_pc.task_script_url
        ssh_password        = random_string.ssh.result
        ssh_password_enable = var.ssh_password_enable
        hosts               = local.hosts
        hostname            = var.app_name
      }))
    })
  }

  allow_stopping_for_update = true
  lifecycle {
    ignore_changes = [metadata["user-data"], boot_disk]
  }
}
