# Google Cloud counterpart of k8s_self_managment_v2: a kubeadm cluster on GCE instances,
# bootstrapped by the same scripts (template/, derived from the AWS ones).
# The instances get no service account: participants have sudo, so there must be no cloud
# credentials to steal. The kubeconfig and the join command are shared over SSH instead of S3.
locals {
  USER_ID     = var.USER_ID == "" ? "defaultUser" : var.USER_ID
  ENV_ID      = var.ENV_ID == "" ? "defaultId" : var.ENV_ID
  name        = module.common.name
  labels      = merge(module.common.labels, { app_name = lower(var.app_name) })
  network_tag = "${local.name}-k8s"
  spot        = var.node_type == "spot"

  master_ip_private = google_compute_instance.master.network_interface[0].network_ip
  master_ip_public  = google_compute_instance.master.network_interface[0].access_config[0].nat_ip
  external_ip       = var.k8s_master.eip == "true" ? google_compute_address.master["enable"].address : ""

  worker_nodes = {
    for key, instance in google_compute_instance.worker :
    key => {
      private_ip     = instance.network_interface[0].network_ip
      public_ip      = instance.network_interface[0].access_config[0].nat_ip
      runtime        = var.k8s_worker[key].runtime
      labels         = var.k8s_worker[key].node_labels
      id             = instance.id
      ubuntu_version = var.k8s_worker[key].ubuntu_version
      instance_type  = local.machine_type[key]
    }
  }
  machine_type = merge(
    { master = lookup(module.common.machine_types, var.k8s_master.instance_type, var.k8s_master.instance_type) },
    { for key, worker in var.k8s_worker : key => lookup(module.common.machine_types, worker.instance_type, worker.instance_type) },
  )

  hosts_worker_node = [for key, value in local.worker_nodes : "${var.cluster_name}_node_${key}=${value.private_ip}"]
  hosts_master_node = ["${var.cluster_name}_controlPlane_1=${local.master_ip_private}"]
  hosts             = concat(local.hosts_master_node, local.hosts_worker_node)

  metadata_common = {
    "block-project-ssh-keys" = "true"
    "enable-oslogin"         = "FALSE"
  }
}

module "common" {
  source     = "../gcp_common"
  name_parts = [local.USER_ID, local.ENV_ID, var.prefix]
  tags       = var.tags_common
}

data "google_compute_image" "master" {
  family  = module.common.image_families[var.k8s_master.ubuntu_version]
  project = "ubuntu-os-cloud"
}

data "google_compute_image" "worker" {
  for_each = var.k8s_worker
  family   = module.common.image_families[each.value.ubuntu_version]
  project  = "ubuntu-os-cloud"
}

resource "random_string" "ssh" {
  length  = 10
  special = false
}

# Same openings as the AWS security group towards the participants: SSH and NodePorts.
# (Traffic inside the lab network is allowed by gcp_network.)
resource "google_compute_firewall" "access" {
  name          = "${local.name}-k8s-access"
  network       = var.vpc_id
  source_ranges = var.k8s_master.cidrs
  target_tags   = [local.network_tag]

  allow {
    protocol = "tcp"
    ports    = ["22", "30000-32767"]
  }
}

resource "google_compute_address" "master" {
  for_each = toset(var.k8s_master.eip == "true" ? ["enable"] : [])
  name     = "${local.name}-master"
  labels   = local.labels
}

resource "google_compute_instance" "master" {
  name           = "${local.name}-master"
  machine_type   = local.machine_type["master"]
  tags           = [local.network_tag]
  labels         = local.labels
  can_ip_forward = true

  boot_disk {
    initialize_params {
      image = data.google_compute_image.master.self_link
      size  = var.k8s_master.root_volume.size
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = var.subnets[tonumber(var.k8s_master.subnet_number)]
    access_config {
      nat_ip = var.k8s_master.eip == "true" ? google_compute_address.master["enable"].address : null
    }
  }

  scheduling {
    provisioning_model          = local.spot ? "SPOT" : "STANDARD"
    preemptible                 = local.spot
    automatic_restart           = !local.spot
    instance_termination_action = local.spot ? "STOP" : null
  }

  metadata = merge(local.metadata_common, {
    "user-data" = templatefile("${path.module}/template/boot_zip.sh", {
      boot_zip = base64gzip(templatefile("${path.module}/${var.k8s_master.user_data_template}", {
        external_ip             = local.external_ip
        k8_version              = var.k8s_master.k8_version
        runtime                 = var.k8s_master.runtime
        utils_enable            = var.k8s_master.utils_enable
        pod_network_cidr        = var.k8s_master.pod_network_cidr
        runtime_script          = file("${path.module}/${var.k8s_master.runtime_script}")
        task_script_url         = var.k8s_master.task_script_url
        cni_type                = var.k8s_master.cni.type
        calico_url              = var.k8s_master.cni.calico_url
        cilium_version          = var.k8s_master.cni.cilium_version
        cilium_helm_version     = var.k8s_master.cni.cilium_helm_version
        disable_kube_proxy      = var.k8s_master.cni.disable_kube_proxy
        ssh_private_key         = var.k8s_master.ssh.private_key
        ssh_pub_key             = var.k8s_master.ssh.pub_key
        ssh_password            = random_string.ssh.result
        ssh_password_enable     = var.ssh_password_enable
        kubeadm_init_extra_args = var.k8s_master.kubeadm_init_extra_args
      }))
    })
  })

  allow_stopping_for_update = true
  lifecycle {
    ignore_changes = [metadata["user-data"], boot_disk]
  }
}

resource "google_compute_instance" "worker" {
  for_each = var.k8s_worker

  name           = substr("${local.name}-${lower(replace(each.key, "/[^a-zA-Z0-9-]/", "-"))}", 0, 63)
  machine_type   = local.machine_type[each.key]
  tags           = [local.network_tag]
  labels         = local.labels
  can_ip_forward = true

  boot_disk {
    initialize_params {
      image = data.google_compute_image.worker[each.key].self_link
      size  = each.value.root_volume.size
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = var.subnets[tonumber(each.value.subnet_number)]
    access_config {}
  }

  scheduling {
    provisioning_model          = local.spot ? "SPOT" : "STANDARD"
    preemptible                 = local.spot
    automatic_restart           = !local.spot
    instance_termination_action = local.spot ? "STOP" : null
  }

  metadata = merge(local.metadata_common, {
    "user-data" = templatefile("${path.module}/template/boot_zip.sh", {
      boot_zip = base64gzip(templatefile("${path.module}/${each.value.user_data_template}", {
        master_ip           = local.master_ip_private
        k8_version          = each.value.k8_version
        runtime             = each.value.runtime
        runtime_script      = file("${path.module}/${each.value.runtime_script}")
        task_script_url     = each.value.task_script_url
        node_name           = each.key
        node_labels         = each.value.node_labels
        ssh_private_key     = each.value.ssh.private_key
        ssh_pub_key         = each.value.ssh.pub_key
        ssh_password        = random_string.ssh.result
        ssh_password_enable = var.ssh_password_enable
      }))
    })
  })

  allow_stopping_for_update = true
  lifecycle {
    ignore_changes = [metadata["user-data"], boot_disk]
  }
}
