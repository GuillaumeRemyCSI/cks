# CLAUDE.md

This file tells Claude Code how to work in this repository.

This repository is a fork of [ViktorUJ/cks](https://github.com/ViktorUJ/cks), used to run the
LFS460 (Kubernetes Security Fundamentals / CKS) course. It contains the CKS labs 101-115, ported to
Ubuntu 24.04 and Kubernetes 1.35.2, plus the classroom tooling in `training/`. That tooling deploys one
isolated environment per participant on Google Cloud (AWS works too but has never been deployed
for real).

**The repository is public.** Never commit:
- participant data, passwords or IPs (`training/out/`, `participants.txt`, `classroom.env` and
  `logs/` are git-ignored on purpose);
- personal details: names, e-mails, billing account;
- official LFS460 course material (slides, lab manual PDF, tarball), which lives outside the repo.

`training/LFS460.md` may only hold *notes about* the exercises, never their content.

## Where things are

| Path | Content |
|---|---|
| `training/classroom.sh` | `preflight` / `up` / `access` / `down` for one or more labs, for every participant |
| `training/README.md` | Trainer guide: setup, GCP specifics, costs and quotas, cleanup check |
| `training/SCHEDULE.md` | 4-day schedule: chapters, CKS homework labs, when to start/stop them |
| `training/LFS460.md` | Trainer notes and known bugs of the official exercises (chapters 2-8) |
| `training/LABS.md` | Notes on each CKS lab 101-115 from the end-to-end runs |
| `tasks/cks/labs/<NNN>/` | One lab: `vpc`, `k8s-1`, `worker` (terragrunt), `worker/files/{tests.bats,solutions,worker.sh}` |
| `terraform/modules/gcp_*` | GCP modules mirroring the AWS module interfaces |
| `terraform/environments-gcp/<id>_<lab>/` | Live per-participant terragrunt dirs (git-ignored, created by `up`) |
| `training/out/<lab>/` | Access sheets: `access.csv` + `<id>.txt` (git-ignored) |

## Running the classroom

Configuration lives in `training/classroom.env` (copy `classroom.env.example`): `CKS_CLOUD=gcp`, the
project, state bucket, region/zone (the org policy only allows `europe-west6`), `CKS_REPO` /
`CKS_REPO_REF` (the VMs download their scripts and tests from that public fork and branch, so push
before deploying), `CKS_ACCESS_CIDRS` (room CIDR; `0.0.0.0/0` for open access, never a bare IP) and
`PARALLEL`.

```bash
training/classroom.sh up 106 112            # every participant in participants.txt
PARTICIPANTS_FILE=/path/p01.txt training/classroom.sh up 106   # a subset
training/classroom.sh up lfs460-cluster     # bare VMs cp + worker, user 'student'
training/classroom.sh access 106            # rebuild the access sheets
training/classroom.sh down 103 104
```

- Lab IDs are `101`-`115`, plus `lfs460-single` (chapters 2-3) and `lfs460-cluster` (chapter 4 onwards).
- `up` runs `preflight`, which needs a **valid gcloud CLI token**. It expires often: ask the user to
  run `! gcloud auth login`. `down` only needs Terraform ADC.
- `up` and `access` **rewrite `training/out/<lab>/access.csv` with only the participants of
  PARTICIPANTS_FILE**. When deploying a subset, save the existing sheet first and merge it back
  afterwards.
- The trainer has its own environment (`trainer`), deployed with a separate PARTICIPANTS_FILE and not
  listed in `participants.txt`.
- A transient Google API error (502) can leave a destroy half done. Rerun `terragrunt destroy` in
  `terraform/environments-gcp/<id>_<lab>/{k8s-1,vpc}` after `set -a; . training/classroom.env` and
  exporting `TF_VAR_USER_ID` / `TF_VAR_ENV_ID`, then remove the directory.
- After a teardown, check that nothing is left:
  `gcloud compute instances list --project <project>`.
- Each `up` or `down` takes several minutes: run it in the background and wait for completion.
- Never destroy or stop a participant's lab unless the trainer asks for it explicitly.

## Working on the lab VMs

- SSH uses passwords from the access sheets: CKS labs log in as user `ubuntu`, LFS460 VMs as `student`.
  Non-interactively, use an `SSH_ASKPASS` helper that echoes `$SSHPW`, with
  `SSH_ASKPASS_REQUIRE=force DISPLAY=x setsid ssh -n -o PubkeyAuthentication=no
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null`. Without `PubkeyAuthentication=no`
  you get "Too many authentication failures".
- Scoring: run `check_result` on the CKS work PC. Strip the ANSI codes and keep the lines
  `ok N` / `not ok N` / `result =`.
- **Timer:** each CKS lab has `exam_time_minutes=360` counted from boot. When it expires, a cron runs
  `/usr/bin/exam_check.sh`, which deletes `~/.kube/config`. The countdown keeps running while the VM
  is stopped. To extend it, replace the 10-digit epoch in both `/usr/bin/exam_check.sh` and
  `/usr/bin/time_left` (`sudo sed -i "s/$OLD/$NEW/"`).
- **Stop/start:** a stopped VM gets a new ephemeral public IP when it restarts. Update `access.csv` and
  `<id>.txt` afterwards. Reserving the address as static fails once the VM is stopped. After a restart,
  pods stay `Unknown` for a few minutes, then recover.
- When reviewing a participant's cluster, stay **read-only** unless the trainer asks you to apply a fix.
- Wait for a fresh lab to be ready before using it: `cloud-init status` must report `done` and
  `check_result` must exist. Package mirrors can make this take more than 10 minutes.

## Known issues in the official LFS460 exercises

The details and workarounds are in `training/LFS460.md`. The ones that come up live:
- **3.6 gVisor:** the `latest/` URLs return 404, so install from the gVisor apt repo. The shim lands in
  `/usr/bin`, not `/usr/local/bin`: remove the empty files the script leaves there. Keep
  `SystemdCgroup = true` and restart containerd.
- **3.2 / 7.1 Trivy:** install a pinned `.deb`.
- **4.4 kube-bench:** set `KUBECONFIG=/etc/kubernetes/admin.conf`.
- **5.6 Auditing:** copy `moderate-policy.yaml` from the tarball. Step 9 re-enables
  `--audit-policy-file`.
- **5.7 Encryption:** rewrite the secrets with `kubectl get secrets -A -o json | kubectl replace -f -`.
- **Manifest backups:** never leave a backup in `/etc/kubernetes/manifests/`. The kubelet runs every
  file there as a static pod, and the old API server may win. Keep backups in `/etc/kubernetes/`.
- **6.1:** use `hostname -I`. The firewall already opens NodePorts 30000-32767.
- **7.4 / 7.5:** Tracee and Falco do not fit together on 2 vCPU nodes, so uninstall Tracee first.
- **7.5 Falco:** `driver.kind=ebpf` is gone, use `modern_ebpf`. The rule fires only with
  `kubectl exec -it` from an interactive SSH session.
- **7.6 AppArmor:** steps 10-14 need docker, which is not installed.

## Conventions

- The trainer chats in French. Docs, scripts, commit messages and participant-facing material are in
  English.
- Branch `formation-lfs460` carries the course changes. Keep commit subjects prefixed by area
  (`training: ...`, `labs: ...`).
- The user's shell is zsh: variables are not word-split (use arrays `(${(f)"$(...)"})`), and
  `$var[...]` is a subscript, so write `${var}[`.
