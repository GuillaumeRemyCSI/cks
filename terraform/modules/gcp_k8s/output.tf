# Outputs used by the lab stacks keep the names of k8s_self_managment_v2.
output "k8s_config" {
  value = "ssh://${local.master_ip_private}"
}

output "hosts" {
  value = local.hosts
}

output "hosts_master_node" {
  value = local.hosts_master_node
}

output "hosts_worker_node" {
  value = local.hosts_worker_node
}

output "cluster" {
  value = var.cluster_name
}

output "master_external_ip" {
  value = local.master_ip_public
}

output "master_local_ip" {
  value = local.master_ip_private
}

output "master_ssh" {
  value = "ssh ubuntu@${local.master_ip_public}  password= ${random_string.ssh.result}  "
}

output "ssh_password" {
  value = "  ${random_string.ssh.result}   "
}

output "worker_nodes" {
  value = local.worker_nodes
}

output "k8_master_version" {
  value = var.k8s_master.k8_version
}

output "node_type" {
  value = var.node_type
}

output "check_node_status" {
  value = "tail -f /var/log/cloud-init-output.log "
}

output "worker_reload_bashrc" {
  value = "  source ~/.bashrc   "
}
