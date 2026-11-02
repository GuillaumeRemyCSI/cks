#!/bin/bash
# --- Google Cloud: GCE images have no 'ubuntu' user, which the labs and their scripts expect.
id ubuntu >/dev/null 2>&1 || useradd -m -s /bin/bash -G sudo,adm ubuntu
echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-cks-ubuntu
chmod 0440 /etc/sudoers.d/90-cks-ubuntu
install -d -m 700 -o ubuntu -g ubuntu /home/ubuntu/.ssh
install -d -m 700 /root/.ssh
# Scripts rename some hosts (work PC, lab 112): keep that name across reboots.
echo "preserve_hostname: true" > /etc/cloud/cloud.cfg.d/99-cks-hostname.cfg
if [[ "${ssh_password_enable}" == "true" ]]; then
  # sshd keeps the first value it reads: this file sorts before 60-cloudimg-settings.conf.
  echo "PasswordAuthentication yes" > /etc/ssh/sshd_config.d/10-cks.conf
fi
# ---
ssh_password_enable_check=${ssh_password_enable}
case  $ssh_password_enable_check in
true)
    echo -e "${ssh_password}\n${ssh_password}" | passwd ubuntu
    SSH_CONFIG_FILE="/etc/ssh/sshd_config"
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' $SSH_CONFIG_FILE
    sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' $SSH_CONFIG_FILE
    systemctl restart ssh
;;
*)
    echo "*** ssh password not enable "
;;
esac

runtime_sh=${runtime}
k8_version_sh=${k8_version}
master_ip_sh=${master_ip}
VERSION="$(echo $k8_version_sh| cut -d'.' -f1).$(echo $k8_version_sh| cut -d'.' -f2)"

echo "${ssh_private_key}">/home/ubuntu/.ssh/id_rsa
chmod 600 /home/ubuntu/.ssh/id_rsa
chown ubuntu:ubuntu /home/ubuntu/.ssh/id_rsa
echo "${ssh_pub_key}">>/home/ubuntu/.ssh/authorized_keys

date
swapoff -a

apt-get update && sudo apt-get upgrade -y
apt-get install -y unzip

${runtime_script}

# add node labels
case $VERSION in
   1.28)
     kubelet_config_url="/usr/lib/systemd/system/kubelet.service.d"
   ;;
   1.29)
     kubelet_config_url="/usr/lib/systemd/system/kubelet.service.d"
   ;;
   1.30)
     kubelet_config_url="/usr/lib/systemd/system/kubelet.service.d"
   ;;
   1.31)
     kubelet_config_url="/usr/lib/systemd/system/kubelet.service.d"
     cat > /etc/default/kubelet  <<EOF
KUBELET_EXTRA_ARGS="--node-labels=node_name=${node_name},${node_labels}"
EOF
;;
   1.32)
     kubelet_config_url="/usr/lib/systemd/system/kubelet.service.d"
     cat > /etc/default/kubelet  <<EOF
KUBELET_EXTRA_ARGS="--node-labels=node_name=${node_name},${node_labels}"
EOF
   ;;
   1.33)
     kubelet_config_url="/usr/lib/systemd/system/kubelet.service.d"
     cat > /etc/default/kubelet  <<EOF
KUBELET_EXTRA_ARGS="--node-labels=node_name=${node_name},${node_labels}"
EOF
   ;;
   1.34)
     kubelet_config_url="/usr/lib/systemd/system/kubelet.service.d"
     cat > /etc/default/kubelet  <<EOF
KUBELET_EXTRA_ARGS="--node-labels=node_name=${node_name},${node_labels}"
EOF
   ;;
   1.35)
     kubelet_config_url="/usr/lib/systemd/system/kubelet.service.d"
     cat > /etc/default/kubelet  <<EOF
KUBELET_EXTRA_ARGS="--node-labels=node_name=${node_name},${node_labels}"
EOF
   ;;
   *)
     kubelet_config_url="/etc/systemd/system/kubelet.service.d"
   ;;
 esac

cat > $kubelet_config_url/20-labels-taints.conf  <<EOF
[Service]
Environment="KUBELET_EXTRA_ARGS=--node-labels=node_name=${node_name},${node_labels}"
EOF
echo "Environment=\"KUBELET_EXTRA_ARGS=--node-labels=node_name=${node_name},${node_labels}\"">/etc/sysconfig/kubelet
systemctl enable kubelet
systemctl restart kubelet

date
echo "wait master ready"
master_ssh="ssh -i /home/ubuntu/.ssh/id_rsa -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 ubuntu@$master_ip_sh"
until $master_ssh test -f cks-bootstrap/ready
  do
   sleep 5
   echo "Wait master ready .Trying again..."
  done
date

$master_ssh cat cks-bootstrap/join_node > worker_join
chmod +x worker_join
./worker_join

# add additional script
curl "${task_script_url}" -o "task.sh"
chmod +x  task.sh
./task.sh
