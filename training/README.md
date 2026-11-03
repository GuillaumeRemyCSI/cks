# CKS training (LFS460): deploying the labs for a class

Changes in this fork compared with the upstream repository:

| Topic | Upstream | Here |
|---|---|---|
| Kubernetes of labs 101-115 | 1.36.0 | **1.35.2**, the same minor as the CKS exam |
| VM operating system | Ubuntu 22.04 | **Ubuntu 24.04** |
| Lab 113 (upgrade) | 1.35.4 → 1.36.x | 1.35.2 → 1.36.x (the topic is still a minor upgrade) |
| Scripts and tests downloaded by the VMs | hard-coded `ViktorUJ/cks@master` | configurable repository and branch (`CKS_REPO`, `CKS_REPO_REF`) |
| SSH access | hard-coded `0.0.0.0/0` | can be restricted to the room (`CKS_ACCESS_CIDRS`) |
| S3 permissions of the VMs | `s3:*` on the whole state bucket (states and passwords of every participant) | read (and write for the master) limited to `config/<participant>/<lab>/` |
| Instructions link in the outputs | Russian README | English README |
| Cloud | AWS only | AWS or **Google Cloud** (`CKS_CLOUD=gcp`, see below) |

To run the labs yourself before the course, see [LABS.md](LABS.md).

## Once, before the course

Steps 2, 3 and 5 below are about AWS. On Google Cloud, follow the
[On Google Cloud](#on-google-cloud) section instead.

1. **Publish this fork.** At boot, the VMs download their scripts and the `check_result` tests
   from GitHub: without a pushed fork they would use the upstream versions (1.36) and the tests
   would fail. The repository must be public.
2. **Terraform state bucket.** Replace `backend_bucket` in
   `terraform/environments/terragrunt.hcl` with a name of your own (globally unique).
   Terragrunt 0.73 creates the bucket and the DynamoDB table if they do not exist.
3. **Tools**: `terraform`, `terragrunt` v0.73.x (the version of the project's Docker runner;
   the Makefile does not work with terragrunt 1.x), `aws`, `jq`, `make`.
4. **Configuration**:
   ```bash
   cp training/classroom.env.example training/classroom.env
   cp training/participants.txt.example training/participants.txt
   ```
   then fill in `CKS_REPO`, `CKS_REPO_REF`, the room's IPv4 and the participant list
   (short ids, no personal data).
5. **AWS quotas** (region `eu-central-1`): one VPC per participant and per lab deployed at the
   same time, while the default quota is **5 VPCs per region**. Also count 4 to 6 vCPUs per
   participant and per lab. The preflight computes the need and compares it with the quotas:
   ```bash
   training/classroom.sh preflight 101 102
   ```
   Request increases several days in advance.
6. **Dry run**: deploy each planned lab for a single participant (`p00` for instance), solve
   it, then run `check_result`. It is the only real validation of the move to 24.04 / 1.35.2.

## During the course

```bash
training/classroom.sh up 107            # deploys lab 107 for each participant
training/classroom.sh access 107        # regenerates the access sheets
training/classroom.sh down 107          # destroys the lab 107 environments
```

### Bare VMs for the official LFS460 exercises

The exercises of the course material run on bare Ubuntu 24.04 VMs, where the participants install
Kubernetes themselves with the LF scripts:

```bash
training/classroom.sh up lfs460-single     # chapters 2-3: one 'single' node
training/classroom.sh down lfs460-single   # at the end of chapter 3 ("two fresh nodes")
training/classroom.sh up lfs460-cluster    # chapter 4 onwards: 'cp' and 'worker' nodes
```

Each participant gets 2 vCPU / 8 GB VMs (t3.large or e2-standard-2) with the `student` user
(passwordless sudo), one SSH password shared by their nodes, and unrestricted traffic between
their nodes. These VMs have no cloud credentials and download nothing from the fork. You give
the participants the credentials to download the course files (cm.lf.training) yourself.

### How it works

`up` runs the preflight, deploys `PARALLEL` participants at a time (allow 10-15 min per wave),
then writes into `training/out/107/` one `<participant>.txt` sheet per person (IP, password,
link to the instructions) and `access.csv`. These files contain passwords and are not versioned.

The logs of each deployment are in `training/logs/<lab>/<participant>.<action>.log`. To
redeploy a single participant, use a participant file that only contains them:

```bash
echo p03 > /tmp/p03.txt
PARTICIPANTS_FILE=/tmp/p03.txt training/classroom.sh up 107
```

Variables given on the command line take precedence over `training/classroom.env`.

**Costs**: remember to run `down` at the end of the day. To check that nothing is left on AWS:

```bash
make cmdb_get_env_all
```

## On Google Cloud

With `CKS_CLOUD="gcp"` in `training/classroom.env`, the same commands (`preflight`, `up`,
`access`, `down`) deploy labs 101-115 and the LFS460 VMs on Google Cloud. The mock exams
(`mock/01-04`) stay on AWS.

### Setup

1. **Project**: create one dedicated to the course, with billing enabled, then enable the
   Compute Engine API:
   ```bash
   gcloud services enable compute.googleapis.com --project <project-id>
   ```
2. **Credentials for Terraform**:
   ```bash
   gcloud auth application-default login
   ```
3. **Configuration**: fill in `CKS_GCP_PROJECT` and `CKS_GCP_STATE_BUCKET` (the state bucket is
   created by `classroom.sh up` if missing), plus `CKS_REPO` / `CKS_REPO_REF` as on AWS.
4. **Region**: if your organization restricts resource locations
   (`constraints/gcp.resourceLocations`), set `CKS_GCP_REGION` / `CKS_GCP_ZONE` to an allowed
   region, otherwise the state bucket and the VMs cannot be created. To see the allowed values:
   ```bash
   gcloud resource-manager org-policies describe gcp.resourceLocations --project <project-id> --effective
   ```
5. **Tools**: `terraform`, `terragrunt` (0.73.x or 1.x), `gcloud`, `jq`.
6. **Quotas**: the preflight compares the need with the project quotas (VPC networks, firewall
   rules) and the regional ones (vCPUs, external IPs). On a recent project, the **external IP**
   quota is often 8 per region, barely enough for 3 participants on one lab. Request increases in
   advance (IAM & Admin > Quotas).

### Differences with AWS

- **No cloud credentials on the VMs**: none has a service account. The master shares the
  kubeconfig and the `kubeadm join` command over SSH (lab-specific key) instead of S3.
- **Machine types**: t3.small → e2-small, t3.medium → e2-medium, t3.large → e2-standard-2
  (same vCPUs and memory).
- **Node names**: the instances are called `cks-<participant>-<lab>-…`; the Kubernetes nodes
  carry that name (instead of `ip-10-…` on AWS).
- **Lab 101**: `169.254.169.254` is the GCE metadata server; the checks are identical (network
  reachability), see the note in the instructions.
- **Boot scripts**: the ones in `terraform/modules/gcp_*/template/` are derived from the AWS
  scripts. If the upstream repository changes the latter, regenerate them:
  ```bash
  python3 terraform/modules/gcp_common/derive_templates.py terraform/modules
  ```

### Checking the cleanup

To check that no VM is left:

```bash
gcloud compute instances list --project <project-id> --filter="name~^cks-"
```
