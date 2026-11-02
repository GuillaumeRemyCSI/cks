#!/bin/bash
set -euo pipefail

# Without this, cloud-init restores the instance name at every boot and kubelet loses its node.
echo "preserve_hostname: true" > /etc/cloud/cloud.cfg.d/99-cks-hostname.cfg
hostnamectl set-hostname ${hostname}
grep -q " ${hostname}$" /etc/hosts || echo "127.0.1.1 ${hostname}" >> /etc/hosts

id student >/dev/null 2>&1 || useradd -m -s /bin/bash -G sudo student
echo "student:${password}" | chpasswd
echo "student ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-student
chmod 0440 /etc/sudoers.d/90-student

# sshd keeps the first value it reads: this file must sort before 60-cloudimg-settings.conf.
echo "PasswordAuthentication yes" > /etc/ssh/sshd_config.d/10-lfs460.conf
systemctl restart ssh
