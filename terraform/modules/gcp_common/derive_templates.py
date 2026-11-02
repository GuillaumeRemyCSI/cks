"""Derive the Google Cloud bootstrap templates from the AWS ones (exact, asserted replacements)."""
import pathlib
import sys

MODULES = pathlib.Path(sys.argv[1])

PRELUDE = '''#!/bin/bash
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
'''


def convert(src, dst, subs):
    text = (MODULES / src).read_text()
    if subs[0] == 'PRELUDE':
        assert text.startswith('#!/bin/bash\n'), src
        text = PRELUDE + text[len('#!/bin/bash\n'):]
        subs = subs[1:]
    for old, new in subs:
        assert text.count(old) == 1, (src, old[:60])
        text = text.replace(old, new)
    (MODULES / dst).write_text(text)
    print('ok', dst)


MASTER_EXCHANGE_AWS = '''aws s3 cp  /root/.kube/config s3://$k8s_config_sh
kubeadm token create --print-join-command --ttl 90000m > join_node
aws s3 cp  join_node s3://$worker_join_sh
'''
MASTER_EXCHANGE_GCP = '''kubeadm token create --print-join-command --ttl 90000m > join_node
# Google Cloud: the worker nodes and the work PC fetch these files over SSH with the lab key,
# so the VMs need no bucket and no cloud credentials.
install -d -m 700 -o ubuntu -g ubuntu /home/ubuntu/cks-bootstrap
install -m 600 -o ubuntu -g ubuntu /root/.kube/config /home/ubuntu/cks-bootstrap/config
install -m 600 -o ubuntu -g ubuntu join_node /home/ubuntu/cks-bootstrap/join_node
touch /home/ubuntu/cks-bootstrap/ready
'''

convert('k8s_self_managment_v2/template/master.sh', 'gcp_k8s/template/master.sh', ['PRELUDE',
    ('local_ipv4=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)\n',
     "local_ipv4=$(ip -4 route get 1.1.1.1 | awk '{for (i = 1; i < NF; i++) if ($i == \"src\") print $(i + 1)}')\n"),
    ('k8s_config_sh=${k8s_config}\nworker_join_sh=${worker_join}\n', ''),
    (MASTER_EXCHANGE_AWS, MASTER_EXCHANGE_GCP),
])

convert('k8s_self_managment_v2/template/worker.sh', 'gcp_k8s/template/worker.sh', ['PRELUDE',
    ('worker_join_sh=${worker_join}\n', 'master_ip_sh=${master_ip}\n'),
    ('''echo "wait master ready"
aws s3 ls s3://$worker_join_sh
while test $? -gt 0
  do
   sleep 5
   echo "Wait master ready .Trying again..."
   aws s3 ls s3://$worker_join_sh
  done
date

echo " aws s3 cp s3://$worker_join_sh  worker_join   "
aws s3 cp s3://$worker_join_sh  worker_join
''', '''echo "wait master ready"
master_ssh="ssh -i /home/ubuntu/.ssh/id_rsa -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 ubuntu@$master_ip_sh"
until $master_ssh test -f cks-bootstrap/ready
  do
   sleep 5
   echo "Wait master ready .Trying again..."
  done
date

$master_ssh cat cks-bootstrap/join_node > worker_join
'''),
])

convert('k8s_self_managment_v2/template/runtime.sh', 'gcp_k8s/template/runtime.sh', [
    ('''echo "*** install aws cli "
acrh=$(uname -m)
case $acrh in
x86_64)
  awscli_url="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
;;
aarch64)
  awscli_url="https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip"
;;
esac
curl $awscli_url  -o "awscliv2.zip" -s
unzip awscliv2.zip >/dev/null
./aws/install >/dev/null
aws --version
''', '''# master.sh reads $acrh after this script (the AWS version sets it while installing aws cli).
acrh=$(uname -m)
'''),
])

WAIT_AWS = '''echo "wait cluster $1 ready"
aws s3 ls $2
while test $? -gt 0
  do
   sleep 10
   echo "wait cluster $1 ready .Trying again..."
   aws s3 ls $2
  done
date
'''
WAIT_GCP = '''echo "wait cluster $1 ready"
until ssh $cks_ssh_opts ubuntu@$(echo "$2" | sed 's#^ssh://##') test -f cks-bootstrap/ready
  do
   sleep 10
   echo "wait cluster $1 ready .Trying again..."
  done
date
'''
WORK_PC_SUBS = ['PRELUDE',
    ('ssh_password_enable_check=${ssh_password_enable}\n',
     'ssh_password_enable_check=${ssh_password_enable}\n'
     '# Google Cloud: cluster configs are fetched over SSH from the masters (see master.sh).\n'
     'cks_ssh_opts="-i /root/.ssh/id_rsa -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5"\n'),
    (WAIT_AWS, WAIT_GCP),
    ('  aws s3 cp $cluster_config_url $cluster_name\n',
     '  ssh $cks_ssh_opts ubuntu@$(echo "$cluster_config_url" | sed \'s#^ssh://##\') cat cks-bootstrap/config > $cluster_name\n'),
    ('''curl $awscli_url  -o "awscliv2.zip" -s
unzip awscliv2.zip >/dev/null
./aws/install >/dev/null
aws --version

echo 'complete -C "/usr/local/bin/aws_completer" aws'>>/root/.bashrc
echo 'complete -C "/usr/local/bin/aws_completer" aws' >>/home/ubuntu/.bashrc
''', ''),
]
convert('work_pc_v2/template/worker.sh', 'gcp_work_pc/template/worker.sh', WORK_PC_SUBS)
convert('work_pc_v2/template/worker_podman_fix.sh', 'gcp_work_pc/template/worker_podman_fix.sh', WORK_PC_SUBS)
