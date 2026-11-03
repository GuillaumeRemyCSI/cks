# CKS labs sheet: running them yourself

Links point to the instructions and solutions on the fork
[GuillaumeRemyCSI/cks@formation-lfs460](https://github.com/GuillaumeRemyCSI/cks/tree/formation-lfs460).
All labs were tested on Google Cloud (europe-west6) on 2026-11-02: deployment, nodes `Ready` in
Kubernetes 1.35.2 and `check_result` work. The solutions themselves still have to be run end to
end: that is what this sheet is for.

## Deploying a lab for yourself

With a participant file that only contains you:

```bash
echo trainer > /tmp/trainer.txt
```

```bash
cd ~/code/cks && PARTICIPANTS_FILE=/tmp/trainer.txt training/classroom.sh up 107
```

The access sheet (IP of the work PC and password) is in `training/out/107/trainer.txt`.
Allow 10 to 15 minutes, then:

```bash
ssh ubuntu@<ip>
```

On the work PC:

- `tail -f /var/log/cloud-init-output.log`: wait for the end of the initialization;
- `source ~/.bashrc`, then `kubectl get nodes`;
- `check_result`: score and hints (`HINT`); `time_left`: remaining time;
- `ssh <node-name>` to log in to a node (names given by `kubectl get nodes`).

When you are done with the lab, destroy it:

```bash
cd ~/code/cks && PARTICIPANTS_FILE=/tmp/trainer.txt training/classroom.sh down 107
```

## Overview

| Lab | Topic | CKS domain | LFS460 chapters | VMs | Timer | Instructions | Solution | Done |
|---|---|---|---|---|---|---|---|---|
| 101 | NetworkPolicy, isolation, metadata | Cluster Setup | 6 | 2 | 6 h | [EN][e101] | [EN][s101] | ☐ |
| 102 | CiliumNetworkPolicy L3/L4/L7, Hubble | Cluster Setup | 6 | 2 | 6 h | [EN][e102] | [EN][s102] | ☐ |
| 103 | CIS/kube-bench, Ingress TLS, binaries | Cluster Setup | 2, 4, 6 | 3 | 6 h | [EN][e103] | [EN][s103] | ☐ |
| 104 | RBAC, ServiceAccount, anonymous-auth | Cluster Hardening | 5, 8 | 2 | 6 h | [EN][e104] | [EN][s104] | ☐ |
| 105 | OS and Docker daemon hardening | System Hardening | (not in the slides) | 3 | 6 h | [EN][e105] | [EN][s105] | ☐ |
| 106 | AppArmor and seccomp | System Hardening | 7 | 2 | 6 h | [EN][e106] | [EN][s106] | ☐ |
| 107 | Pod Security Admission | Microservice Vulnerabilities | 5 | 2 | 6 h | [EN][e107] | [EN][s107] | ☐ |
| 108 | Kyverno, Gatekeeper, ImagePolicyWebhook | Microservice Vulnerabilities | 4, 5 | 2 | 6 h | [EN][e108] | [EN][s108] | ☐ |
| 109 | Encrypting Secrets in etcd | Microservice Vulnerabilities | 5 | 2 | 6 h | [EN][e109] | [EN][s109] | ☐ |
| 110 | gVisor, Cilium WireGuard, Istio mTLS | Microservice Vulnerabilities | 3, 6 | 3 | 6 h | [EN][e110] | [EN][s110] | ☐ |
| 111 | Image analysis, SBOM, supply chain | Supply Chain Security | 3, 7 | 2 | 6 h | [EN][e111] | [EN][s111] | ☐ |
| 112 | Falco, audit logs, immutable filesystem | Monitoring & Runtime | 5, 7, 8 | 2 | 6 h | [EN][e112] | [EN][s112] | ☐ |
| 113 | kubeadm upgrade 1.35 → 1.36 | Cluster Hardening | 4 (theory) | 3 | 2 h | [EN][e113] | [EN][s113] | ☐ |
| 114 | kubeconfig contexts, client certificates | Cluster Hardening | (not in the slides) | 2 | 6 h | [EN][e114] | [EN][s114] | ☐ |
| 115 | Cilium without kube-proxy, Mutual Auth | Cluster Setup | 6 | 2 | 6 h | [EN][e115] | [EN][s115] | ☐ |

The timer is the `time_left` countdown (after which the kubeconfig is removed), not the time you
need: plan 1 to 2 hours per lab to run it.

## Lab by lab

### 101 - NetworkPolicy: default-deny, isolation, and cloud metadata

- [Instructions][e101] · [Solution][s101] · 7 tasks
- On GCP, `169.254.169.254` is the GCE metadata server: the behaviour to observe is the same
  (note in the instructions).
- Fully checked on the platform side: DNS, API, metadata and `check_result` tested from a pod.

### 102 - CiliumNetworkPolicy: L3/L4/L7, DNS-aware egress, and Hubble

- [Instructions][e102] · [Solution][s102] · 6 tasks
- Run it first: Cilium depends on the cloud network.

### 103 - CIS/kube-bench, Secure Ingress TLS, and binary verification

- [Instructions][e103] · [Solution][s103] · 10 tasks
- Course: [Chapter 07. CIS Benchmark and kube-bench][c07],
  [Chapter 08. Secure Ingress with TLS][c08],
  [Chapter 09. Insecure component arguments, TLS hardening, and binary verification][c09]
- Two-node cluster (control-plane + worker). The worker script was fixed (it never finished):
  check that task 10, on the worker, goes well.

### 104 - Restricting access to the Kubernetes API

- [Instructions][e104] · [Solution][s104] · 12 tasks

### 105 - System Hardening of the OS and Docker daemon security

- [Instructions][e105] · [Solution][s105] · 10 tasks
- Course: [Chapter 14. Minimizing host OS footprint and runtime daemon security][c14],
  [Chapter 15. Host least privilege and minimizing external network access][c15]
- Extra `docker-host` VM, with a Docker daemon deliberately exposed on TCP/2375.

### 106 - AppArmor and seccomp

- [Instructions][e106] · [Solution][s106] · 9 tasks
- Course: [Chapter 16. AppArmor][c16], [Chapter 17. seccomp][c17],
  [Chapter 03. Linux security mechanisms under the hood][c03]
- Ubuntu 24.04 ships AppArmor 4: check that the solution's profiles load.

### 107 - Pod Security Admission

- [Instructions][e107] · [Solution][s107] · 7 tasks
- The PSA labels use `v1.35`, the version of the cluster and of the exam.

### 108 - Admission policies with Kyverno

- [Instructions][e108] · [Solution][s108] · 7 tasks
- Also covers Gatekeeper (task 7) and ImagePolicyWebhook (task 6), exercises 4.5 and 5.5 of the
  slides.

### 109 - Encrypting Secrets in etcd and minimal access

- [Instructions][e109] · [Solution][s109] · 5 tasks

### 110 - gVisor RuntimeClass, Cilium WireGuard, and Istio mTLS

- [Instructions][e110] · [Solution][s110] · 6 tasks
- Course: [Chapter 22. Container Runtime Sandbox][c22],
  [Chapter 23. Pod-to-Pod encryption and mTLS][c23]
- Dedicated `gvisor` node; run it first (gVisor, WireGuard and Istio depend on the VM and the
  network).

### 111 - Image analysis, static fixes, and supply-chain evidence

- [Instructions][e111] · [Solution][s111] · 8 tasks
- The participants use rootless podman: watch out on Ubuntu 24.04 (AppArmor restrictions on user
  namespaces).
- The slowest to initialize (downloads the tools and the images to scan).

### 112 - Runtime: Falco, audit logs, and an immutable root filesystem

- [Instructions][e112] · [Solution][s112] · 10 tasks
- Course: [Chapter 29. Falco][c29], [Chapter 30. Threat detection][c30],
  [Chapter 31. Container immutability at runtime][c31], [Chapter 32. Kubernetes audit logs][c32],
  [Chapter 26. Supply-chain security][c26]

### 113 - Upgrading a Kubernetes Cluster with kubeadm

- [Instructions][e113] · [Solution][s113] · 4 tasks
- Course: [Chapter 13. Upgrading Kubernetes to remediate vulnerabilities][c13]
- The cluster starts on 1.35.2 and is upgraded to 1.36.x. 2-hour timer.
- Worker script fixed as for lab 103.

### 114 - Kubeconfig contexts, client certificates, and API exposure

- [Instructions][e114] · [Solution][s114] · 4 tasks
- At startup, `kubectl` deliberately points to `staging.cks114.invalid`: that is the exercise.

### 115 - Cilium bootstrap, kube-proxy replacement, and Mutual Authentication

- [Instructions][e115] · [Solution][s115] · 6 tasks
- At startup, CoreDNS is `Pending`: this is expected, you have to install Cilium (task 1).
- Run it first (Cilium without kube-proxy).

## Suggested order for your runs

1. The labs that depend most on the cloud: **115, 102, 110**, then **113**.
2. The ones that touch the node OS (Ubuntu 24.04): **106, 105, 111, 112**.
3. The others: 101, 103, 104, 107, 108, 109, 114.

If a lab gets stuck, note the `HINT` message of `check_result` and the end of
`/var/log/cloud-init-output.log` on the VM concerned.

[e101]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/101/README.MD
[s101]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/101/worker/files/solutions/1.MD
[e102]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/102/README.MD
[s102]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/102/worker/files/solutions/1.MD
[e103]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/103/README.MD
[s103]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/103/worker/files/solutions/1.MD
[e104]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/104/README.MD
[s104]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/104/worker/files/solutions/1.MD
[e105]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/105/README.MD
[s105]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/105/worker/files/solutions/1.MD
[e106]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/106/README.MD
[s106]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/106/worker/files/solutions/1.MD
[e107]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/107/README.MD
[s107]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/107/worker/files/solutions/1.MD
[e108]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/108/README.MD
[s108]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/108/worker/files/solutions/1.MD
[e109]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/109/README.MD
[s109]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/109/worker/files/solutions/1.MD
[e110]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/110/README.MD
[s110]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/110/worker/files/solutions/1.MD
[e111]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/111/README.MD
[s111]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/111/worker/files/solutions/1.MD
[e112]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/112/README.MD
[s112]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/112/worker/files/solutions/1.MD
[e113]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/113/README.MD
[s113]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/113/worker/files/solutions/1.MD
[e114]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/114/README.MD
[s114]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/114/worker/files/solutions/1.MD
[e115]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/115/README.MD
[s115]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/115/worker/files/solutions/1.MD
[c03]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/course/03/README.md
[c07]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/course/07/README.md
[c08]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/course/08/README.md
[c09]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/course/09/README.md
[c13]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/course/13/README.md
[c14]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/course/14/README.md
[c15]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/course/15/README.md
[c16]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/course/16/README.md
[c17]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/course/17/README.md
[c22]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/course/22/README.md
[c23]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/course/23/README.md
[c26]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/course/26/README.md
[c29]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/course/29/README.md
[c30]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/course/30/README.md
[c31]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/course/31/README.md
[c32]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/course/32/README.md
