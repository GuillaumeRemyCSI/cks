# LFS460 Kubernetes Security Fundamentals: 4-day schedule

Days 1-3: 9:00-17:00. Day 4: 9:00-16:00. Numbers such as **4.2** refer to the exercises of the
LFS460 lab manual. Homework labs are the CKS labs of this repository (see [LABS.md](LABS.md)):
plan 1 to 2 hours per lab. **Core** labs go with the day's topics; **optional** labs are for
participants who want more practice, during the course or afterwards.

**Availability**: each evening's homework lab is ready at the end of the day and is **destroyed the
next day at noon**; labs 101 and 107 stay up until the end of day 4. Optional and after-course
labs are deployed on request: ask the trainer.

## Day 1: Cloud security overview, preparing to install (VM `single`)

| Time | Content |
|---|---|
| 9:00-9:30 | Ch. 1 Introduction, SSH access to the lab VMs |
| 9:30-11:00 | Ch. 2 Cloud Security Overview |
| 11:00-11:15 | Break |
| 11:15-12:00 | Labs 2.1-2.4 (group discussion), 2.5 Use First Node |
| 12:00-13:00 | Lunch |
| 13:00-13:45 | Ch. 3 Preparing to Install |
| 13:45-14:30 | Labs 3.1-3.5 (3.2 Trivy hands-on, the others reading and discussion) |
| 14:30-14:45 | Break |
| 14:45-16:30 | Labs 3.6 Leverage Secure Runtimes (single-node install), 3.7 Kubescape |
| 16:30-17:00 | Buffer, questions |

**Homework**
- Core: [105][e105] OS and Docker daemon hardening (not covered by the slides, part of the CKS
  System Hardening domain)

## Day 2: Installing the cluster, securing the kube-apiserver (VMs `cp` / `worker`)

| Time | Content |
|---|---|
| 9:00-9:40 | Ch. 4 Installing the Cluster |
| 9:40-11:00 | Labs 4.1-4.3 Deploy and configure the two-node cluster |
| 11:00-11:15 | Break |
| 11:15-12:30 | Labs 4.4 kube-bench, 4.5 OPA Gatekeeper |
| 12:30-13:30 | Lunch |
| 13:30-15:00 | Ch. 5 Securing the kube-apiserver |
| 15:00-15:15 | Break |
| 15:15-17:00 | Labs 5.1 RBAC, 5.2 Service Accounts, 5.3 Security Context |

**Homework**
- Core: [103][e103] CIS/kube-bench, Ingress TLS, binary verification
- Core: [104][e104] RBAC, ServiceAccount tokens, anonymous-auth
- Optional: [113][e113] kubeadm upgrade 1.35 → 1.36 (2-hour timer)
- Optional: [114][e114] kubeconfig contexts and client certificates (not covered by the slides)

## Day 3: kube-apiserver (end), networking, workloads (start)

| Time | Content |
|---|---|
| 9:00-10:45 | Labs 5.4 Pod Security Admission, 5.5 ImagePolicyWebhook, 5.6 API Server Auditing |
| 10:45-11:00 | Break |
| 11:00-11:45 | Lab 5.7 Encrypting Secrets |
| 11:45-12:30 | Ch. 6 Networking (6.1-6.3) |
| 12:30-13:30 | Lunch |
| 13:30-14:00 | Ch. 6 Networking (6.4-6.6) |
| 14:00-15:45 | Labs 6.1 Network Policy, 6.2-6.3 Ingress and TLS, 6.4 mTLS |
| 15:45-16:00 | Break |
| 16:00-17:00 | Ch. 7 Workload Considerations (7.1-7.5) |

**Homework**
- Core: [101][e101] NetworkPolicy, default-deny, cloud metadata
- Core: [107][e107] Pod Security Admission, read-only root filesystem
- Optional: [109][e109] Encrypting Secrets in etcd
- Optional: [108][e108] Kyverno, Gatekeeper, ImagePolicyWebhook
- Optional: [102][e102] CiliumNetworkPolicy L3/L4/L7, Hubble
- Optional: [110][e110] gVisor, Cilium WireGuard, Istio mTLS
- Optional: [115][e115] Cilium without kube-proxy, Mutual Authentication

## Day 4: Workloads, issue detection, exam preparation (ends at 16:00)

| Time | Content |
|---|---|
| 9:00-9:30 | Ch. 7 Workload Considerations (7.6-7.9) |
| 9:30-10:30 | Labs 7.1 Image Analysis With Trivy, 7.2 SBOM Scanning, 7.5 Falco |
| 10:30-10:45 | Break |
| 10:45-12:15 | Lab 7.6 AppArmor Profiles; demo of 7.3 BOM tool and 7.4 Tracee |
| 12:15-13:15 | Lunch |
| 13:15-13:50 | Ch. 8 Issue Detection |
| 13:50-14:50 | Labs 8.1 Enumerating and Escalating Privileges, 8.2 Incident Response |
| 14:50-15:00 | Break |
| 15:00-15:45 | Ch. 9 Domain Reviews (9.1, 9.2), exam tips |
| 15:45-16:00 | Ch. 10 Evaluation survey, closing |

**After the course**
- Core: [106][e106] AppArmor and seccomp
- Core: [112][e112] Falco, audit logs, immutable root filesystem
- Core: [111][e111] Image analysis, SBOM, supply chain
- Any optional lab not done during the week

## Homework summary

| Evening | Core | Optional |
|---|---|---|
| Day 1 | 105 | |
| Day 2 | 103, 104 | 113, 114 |
| Day 3 | 101, 107 | 108, 109, 102, 110, 115 |
| After day 4 | 106, 111, 112 | leftovers |

[e101]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/101/README.MD
[e102]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/102/README.MD
[e103]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/103/README.MD
[e104]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/104/README.MD
[e105]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/105/README.MD
[e106]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/106/README.MD
[e107]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/107/README.MD
[e108]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/108/README.MD
[e109]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/109/README.MD
[e110]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/110/README.MD
[e111]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/111/README.MD
[e112]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/112/README.MD
[e113]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/113/README.MD
[e114]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/114/README.MD
[e115]: https://github.com/GuillaumeRemyCSI/cks/blob/formation-lfs460/tasks/cks/labs/115/README.MD
