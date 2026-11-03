#!/usr/bin/env bash
# Deploys the CKS labs for a class: one isolated environment per participant.
# Relies on the USER_ID / ENV_ID mechanism of the Makefile (see docs/multiple_users_envs.MD).
#
#   training/classroom.sh preflight 107
#   training/classroom.sh up 107 108
#   training/classroom.sh access 107
#   training/classroom.sh down 107 108
#
# Bare VMs for the official LFS460 exercises (Ubuntu 24.04, 2 vCPU / 8 GB, user student):
#   training/classroom.sh up lfs460-single     node 'single' (chapters 2-3)
#   training/classroom.sh up lfs460-cluster    nodes 'cp' and 'worker' (chapter 4 onwards)
#
# Cloud: AWS by default, Google Cloud with CKS_CLOUD=gcp (see training/README.md).
# Configuration: training/classroom.env (copy classroom.env.example).
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
TRAINING_DIR="$ROOT/training"
CONF=${CKS_CLASSROOM_CONF:-$TRAINING_DIR/classroom.env}
# Variables given on the command line (PARTICIPANTS_FILE=... classroom.sh up 107)
# take precedence over classroom.env.
overrides=()
for var in PARTICIPANTS_FILE PARALLEL CKS_CLOUD CKS_REPO CKS_REPO_REF CKS_ACCESS_CIDRS \
  CKS_GCP_PROJECT CKS_GCP_STATE_BUCKET CKS_GCP_REGION CKS_GCP_ZONE; do
  [[ -n "${!var+x}" ]] && overrides+=("$var=${!var}")
done
# shellcheck disable=SC1090
[[ -f "$CONF" ]] && . "$CONF"
for override in ${overrides[@]+"${overrides[@]}"}; do export "$override"; done

PARTICIPANTS_FILE=${PARTICIPANTS_FILE:-$TRAINING_DIR/participants.txt}
PARALLEL=${PARALLEL:-4}
CKS_REPO_REF=${CKS_REPO_REF:-master}
OUT_DIR="$TRAINING_DIR/out"
LOG_DIR="$TRAINING_DIR/logs"
UPSTREAM_REPO="ViktorUJ/cks"
UPSTREAM_BUCKET="sre-learning-platform-state-backet"
CKS_CLOUD=${CKS_CLOUD:-aws}
CKS_GCP_REGION=${CKS_GCP_REGION:-europe-west1}
CKS_GCP_ZONE=${CKS_GCP_ZONE:-europe-west1-b}
[[ "$CKS_CLOUD" == aws || "$CKS_CLOUD" == gcp ]] || { echo "ERROR: CKS_CLOUD must be aws or gcp" >&2; exit 1; }
export CKS_REPO CKS_REPO_REF CKS_CLOUD CKS_GCP_PROJECT CKS_GCP_STATE_BUCKET CKS_GCP_REGION CKS_GCP_ZONE
# gcloud asks questions (enable an API, etc.) that nobody would see: make it fail instead.
export CLOUDSDK_CORE_DISABLE_PROMPTS=1

# IPv4 CIDRs only (the VMs have no IPv6); a bare address becomes a /32.
if [[ -n "${CKS_ACCESS_CIDRS:-}" ]]; then
  cidrs=""
  IFS=',' read -ra parts <<<"${CKS_ACCESS_CIDRS// /}"
  for cidr in "${parts[@]}"; do
    if [[ "$cidr" == *:* ]]; then
      echo "ERROR: CKS_ACCESS_CIDRS: $cidr is an IPv6 address, but the VMs only have IPv4 (your IPv4: curl -4 -s ifconfig.me)" >&2
      exit 1
    fi
    [[ "$cidr" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}(/[0-9]{1,2})?$ ]] || { echo "ERROR: CKS_ACCESS_CIDRS: '$cidr' is not an IPv4 CIDR" >&2; exit 1; }
    [[ "$cidr" == */* ]] || cidr="$cidr/32"
    cidrs+="${cidrs:+,}$cidr"
  done
  export CKS_ACCESS_CIDRS=$cidrs
fi

die() { echo "ERROR: $*" >&2; exit 1; }
warn() { echo "WARNING: $*" >&2; }

usage() {
  sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
  exit 1
}

participants() {
  [[ -f "$PARTICIPANTS_FILE" ]] || die "participant list not found: $PARTICIPANTS_FILE"
  local id
  grep -vE '^[[:space:]]*(#|$)' "$PARTICIPANTS_FILE" | tr -d ' \r' | while read -r id; do
    # The id ends up in cloud resource names and state paths.
    [[ "$id" =~ ^[a-z0-9][a-z0-9-]{0,19}$ ]] || die "invalid id '$id' (a-z, 0-9, '-', 20 characters max)"
    echo "$id"
  done
}

# The bare LFS460 VMs do not go through the Makefile, which only knows tasks/cks/labs.
is_nodes() { [[ "$1" == lfs460-* ]]; }

# The Makefile only handles the labs on AWS: everything else is deployed by run_stack.
uses_make() { [[ "$CKS_CLOUD" == aws ]] && ! is_nodes "$1"; }

# Each cloud has its own terragrunt root configuration (S3 or GCS state), found by walking up the tree.
env_root() { if [[ "$CKS_CLOUD" == gcp ]]; then echo "$ROOT/terraform/environments-gcp"; else echo "$ROOT/terraform/environments"; fi; }

stack_dir() {
  if is_nodes "$1"; then echo "$ROOT/tasks/cks/lfs460/${1#lfs460-}"; else echo "$ROOT/tasks/cks/labs/$1"; fi
}

check_lab() {
  [[ "$1" =~ ^([0-9]{3}|lfs460-(single|cluster))$ && -f "$(stack_dir "$1")/env.hcl" ]] ||
    die "unknown lab: $1 (expected: 101 to 115, lfs460-single or lfs460-cluster)"
}

env_dir() {
  if uses_make "$2"; then echo "$(env_root)/${1}_${2}_cks-labs"; else echo "$(env_root)/${1}_${2}"; fi
}

lab_region() {
  if [[ "$CKS_CLOUD" == gcp ]]; then echo "$CKS_GCP_REGION"; return; fi
  grep -E '^\s*region\s*=' "$(stack_dir "$1")/env.hcl" | head -1 | awk -F'"' '{print $2}'
}

# GCP firewall rules of a lab: one for the network, plus one per group of VMs.
lab_firewalls() {
  local dir count=1
  for dir in "$(stack_dir "$1")"/*/; do
    case "$(basename "$dir")" in k8s-* | worker | docker-host | nodes) count=$((count + 1)) ;; esac
  done
  echo "$count"
}

# Number of VMs of a lab, all with 2 vCPUs: one VM per instance type reference,
# or per declared node for the LFS460 VMs.
lab_instances() {
  if is_nodes "$1"; then
    grep -E '^\s*nodes\s*=' "$(stack_dir "$1")/env.hcl" | grep -o '"[a-z]*"' | wc -l | tr -d ' '
  else
    grep -hoE 'instance_type[a-z_]* *= *local\.vars\.locals\.instance_type' "$(stack_dir "$1")"/*/terragrunt.hcl | wc -l | tr -d ' '
  fi
}

aws_quota() {
  aws service-quotas get-service-quota --region "$1" --service-code "$2" --quota-code "$3" \
    --query 'Quota.Value' --output text 2>/dev/null | cut -d. -f1
}

# "<limit> <used>" of a GCP quota, regional (CPUS, IN_USE_ADDRESSES) or project-wide (NETWORKS, FIREWALLS).
gcp_quota() {
  local json
  if [[ "$1" == project ]]; then
    json=$(gcloud compute project-info describe --project "$CKS_GCP_PROJECT" --format=json 2>/dev/null) || return 0
  else
    json=$(gcloud compute regions describe "$1" --project "$CKS_GCP_PROJECT" --format=json 2>/dev/null) || return 0
  fi
  jq -r --arg m "$2" '.quotas[] | select(.metric == $m) | "\(.limit | floor) \(.usage | floor)"' <<<"$json"
}

preflight_aws() {
  local arn bucket
  arn=$(aws sts get-caller-identity --query Arn --output text) || die "no AWS access (aws configure / AWS_PROFILE)"
  echo "AWS: $arn"
  bucket=$(grep '^  backend_bucket' "$ROOT/terraform/environments/terragrunt.hcl" | awk -F'"' '{print $2}')
  if [[ "$bucket" == "$UPSTREAM_BUCKET" ]]; then
    echo "  - backend_bucket is the upstream project's: set your own name in terraform/environments/terragrunt.hcl"
    errors=$((errors + 1))
  else
    echo "Terraform state: s3://$bucket"
  fi
}

preflight_gcp() {
  [[ -n "${CKS_GCP_PROJECT:-}" ]] || die "CKS_GCP_PROJECT is not set (training/classroom.env)"
  [[ -n "${CKS_GCP_STATE_BUCKET:-}" ]] || die "CKS_GCP_STATE_BUCKET is not set (training/classroom.env)"
  gcloud auth application-default print-access-token >/dev/null 2>&1 ||
    die "no credentials for Terraform: gcloud auth application-default login"
  gcloud projects describe "$CKS_GCP_PROJECT" --format='value(projectId)' >/dev/null 2>&1 ||
    die "GCP project not accessible: $CKS_GCP_PROJECT"
  echo "Google Cloud: project $CKS_GCP_PROJECT, $CKS_GCP_REGION / $CKS_GCP_ZONE"
  [[ -n "$(gcloud services list --enabled --project "$CKS_GCP_PROJECT" \
    --filter="config.name=compute.googleapis.com" --format='value(config.name)' 2>/dev/null)" ]] ||
    die "Compute Engine API disabled: gcloud services enable compute.googleapis.com --project $CKS_GCP_PROJECT"
  if gcloud storage buckets describe "gs://$CKS_GCP_STATE_BUCKET" --project "$CKS_GCP_PROJECT" >/dev/null 2>&1; then
    echo "Terraform state: gs://$CKS_GCP_STATE_BUCKET"
  else
    echo "Terraform state: gs://$CKS_GCP_STATE_BUCKET (will be created by up)"
  fi
}

# Compares a need with what is left of a quota: check_need <label> <need> <limit> <used>.
# An empty limit (unreadable quota) is reported without blocking.
check_need() {
  local label=$1 need=$2 limit=${3:-} used=${4:-0}
  if [[ -z "$limit" ]]; then
    echo "  $label: need $need, unknown quota (check it in the console)"
    return
  fi
  echo "  $label: need $need, available $((limit - used)) (quota $limit)"
  if ((need > limit - used)); then
    echo "  - insufficient quota: $label (request an increase in the console)"
    errors=$((errors + 1))
  fi
}

cmd_preflight() {
  local errors=0 tool lab
  local tools="terraform terragrunt jq curl"
  if [[ "$CKS_CLOUD" == gcp ]]; then tools+=" gcloud"; else tools+=" make aws"; fi
  for tool in $tools; do
    command -v "$tool" >/dev/null || { echo "  - missing tool: $tool"; errors=$((errors + 1)); }
  done
  ((errors == 0)) || die "install the missing tools (terragrunt: v0.73.x or 1.x)"

  "preflight_$CKS_CLOUD"

  # The LFS460 VMs download nothing from the fork: the check only applies to labs 101-115.
  local needs_repo=$(($# == 0))
  for lab in "$@"; do is_nodes "$lab" || needs_repo=1; done
  if ((needs_repo == 0)); then
    :
  elif [[ -z "${CKS_REPO:-}" || "$CKS_REPO" == "$UPSTREAM_REPO" ]]; then
    echo "  - CKS_REPO must point to your fork: the VMs download the adapted scripts and tests from it (K8s 1.35)"
    errors=$((errors + 1))
  else
    local raw="https://raw.githubusercontent.com/$CKS_REPO/$CKS_REPO_REF/tasks/cks/labs/101/env.hcl"
    if curl -fsSL "$raw" 2>/dev/null | grep -q 'k8_version = "1.35.2"'; then
      echo "Script repository: $CKS_REPO@$CKS_REPO_REF (adaptations present)"
    else
      echo "  - $raw is not reachable or lacks the adaptations: push the branch $CKS_REPO_REF (public repository)"
      errors=$((errors + 1))
    fi
  fi

  echo "SSH allowed from: ${CKS_ACCESS_CIDRS:-0.0.0.0/0 (the whole Internet)}"

  local n
  n=$(participants | wc -l | tr -d ' ')
  ((n > 0)) || die "no participant in $PARTICIPANTS_FILE"
  echo "Participants: $n"

  if (($# > 0)); then
    local region networks=0 vms=0 firewalls=0
    for lab in "$@"; do
      check_lab "$lab"
      region=$(lab_region "$lab")
      networks=$((networks + n))
      vms=$((vms + n * $(lab_instances "$lab")))
      firewalls=$((firewalls + n * $(lab_firewalls "$lab")))
    done
    # All labs are in the same region; all VMs have 2 vCPUs.
    echo "Quotas ($region):"
    if [[ "$CKS_CLOUD" == gcp ]]; then
      # shellcheck disable=SC2046 # gcp_quota returns "<limit> <used>"
      check_need "VPC networks (project)" "$networks" $(gcp_quota project NETWORKS)
      # shellcheck disable=SC2046
      check_need "firewall rules (project)" "$firewalls" $(gcp_quota project FIREWALLS)
      # shellcheck disable=SC2046
      check_need "vCPUs" "$((vms * 2))" $(gcp_quota "$region" CPUS)
      # shellcheck disable=SC2046
      check_need "external IPs" "$vms" $(gcp_quota "$region" IN_USE_ADDRESSES)
    else
      local used_vpcs
      used_vpcs=$(aws ec2 describe-vpcs --region "$region" --query 'length(Vpcs)' --output text)
      check_need "VPCs" "$networks" "$(aws_quota "$region" vpc L-F678F1CE)" "$used_vpcs"
      check_need "on-demand vCPUs" "$((vms * 2))" "$(aws_quota "$region" ec2 L-1216C47A)" 0
    fi
  fi

  ((errors == 0)) || die "$errors blocking issue(s)"
  echo "Preflight OK"
}

# Run in parallel by xargs, once per participant.
cmd_one() {
  local action=$1 lab=$2 id=$3 log status
  mkdir -p "$LOG_DIR/$lab"
  log="$LOG_DIR/$lab/$id.$action.log"
  # Without a terminal, the confirmation prompt of 'terragrunt run-all' would fail.
  export TERRAGRUNT_NON_INTERACTIVE=true TG_NON_INTERACTIVE=true
  if ! uses_make "$lab"; then
    run_stack "$action" "$lab" "$id" >"$log" 2>&1 </dev/null && status=OK || status=FAILED
  elif (cd "$ROOT" && USER_ID="$id" ENV_ID="$lab" TASK="$lab" make "${action}_cks_task") >"$log" 2>&1 </dev/null; then
    status=OK
  else
    status=FAILED
  fi
  echo "$status" >"$LOG_DIR/$lab/$id.$action.status"
  echo "[$lab] $id: $action $status"
}

# Makefile equivalent (LFS460 VMs, labs on GCP): copies the stack under the terragrunt root
# of the selected cloud, then applies or destroys it.
run_stack() {
  local action=$1 lab=$2 id=$3 dir
  dir=$(env_dir "$id" "$lab")
  mkdir -p "$dir"
  cp -r "$(stack_dir "$lab")"/* "$dir"
  export TF_VAR_USER_ID="$id" TF_VAR_ENV_ID="$lab"
  # terragrunt 1.x replaced run-all (version 0.73 of the repo) with run --all.
  # (no pipe into grep -q: with pipefail, the SIGPIPE received by terragrunt would skew the test)
  local all="run-all" help
  help=$(terragrunt run --help 2>/dev/null || true)
  [[ "$help" == *"--all"* ]] && all="run --all"
  case "$action" in
    # shellcheck disable=SC2086 # $all holds the subcommand and its flag
    run) (cd "$dir" && terragrunt $all apply) ;;
    # shellcheck disable=SC2086
    delete) (cd "$dir" && terragrunt $all destroy) && rm -rf "$dir" ;;
  esac
}

run_all() {
  local action=$1 lab id failed
  shift
  for lab in "$@"; do
    check_lab "$lab"
    echo "== Lab $lab: $action for $(participants | wc -l | tr -d ' ') participant(s), $PARALLEL in parallel"
    participants | xargs -P "$PARALLEL" -I{} "$BASH" "$0" _one "$action" "$lab" {}
    failed=$(participants | while read -r id; do
      [[ "$(cat "$LOG_DIR/$lab/$id.$action.status" 2>/dev/null)" == OK ]] || echo "$id"
    done)
    if [[ -n "$failed" ]]; then
      warn "lab $lab, $action failed for: $(echo $failed) (logs: $LOG_DIR/$lab/<id>.$action.log)"
      FAILED=1
    fi
  done
}

# terragrunt 1.x no longer creates the state bucket (0.73 did): create it ourselves,
# versioned so that a damaged state can be recovered.
ensure_gcp_state_bucket() {
  local bucket="gs://$CKS_GCP_STATE_BUCKET"
  gcloud storage buckets describe "$bucket" --project "$CKS_GCP_PROJECT" >/dev/null 2>&1 && return
  echo "Creating the state bucket $bucket"
  gcloud storage buckets create "$bucket" --project "$CKS_GCP_PROJECT" --location "$CKS_GCP_REGION" \
    --uniform-bucket-level-access --public-access-prevention >/dev/null || die "cannot create $bucket"
  gcloud storage buckets update "$bucket" --versioning >/dev/null || die "cannot enable versioning on $bucket"
}

cmd_up() {
  (($# > 0)) || usage
  cmd_preflight "$@"
  [[ "$CKS_CLOUD" == gcp ]] && ensure_gcp_state_bucket
  run_all run "$@"
  local lab
  for lab in "$@"; do cmd_access "$lab"; done
}

cmd_down() {
  (($# > 0)) || usage
  run_all delete "$@"
}

cmd_access() {
  local lab=${1:-} id dir ssh ip password sheet csv
  [[ -n "$lab" ]] || usage
  check_lab "$lab"
  if is_nodes "$lab"; then
    access_nodes "$lab"
    return
  fi
  mkdir -p "$OUT_DIR/$lab"
  csv="$OUT_DIR/$lab/access.csv"
  echo "participant;ip;password" >"$csv"
  while read -r id; do
    dir="$(env_dir "$id" "$lab")/worker"
    ssh=""
    [[ -d "$dir" ]] && ssh=$(cd "$dir" && terragrunt output -raw worker_pc_ssh 2>/dev/null | grep -oE 'ssh ubuntu@[0-9.]+ password= [^ ]+' || true)
    if [[ -z "$ssh" ]]; then
      warn "lab $lab: no access found for $id (environment not deployed?)"
      continue
    fi
    ip=$(echo "$ssh" | sed -E 's/ssh ubuntu@([0-9.]+).*/\1/')
    password=$(echo "$ssh" | sed -E 's/.*password= //')
    echo "$id;$ip;$password" >>"$csv"
    sheet="$OUT_DIR/$lab/$id.txt"
    cat >"$sheet" <<EOF
CKS training - lab $lab - $id

Instructions : https://github.com/${CKS_REPO:-$UPSTREAM_REPO}/blob/$CKS_REPO_REF/tasks/cks/labs/$lab/README.MD
Connection   : ssh ubuntu@$ip
Password     : $password

On the work PC:
  time_left      time remaining
  check_result   checks your answers and gives your score
If the machine has just started, wait for the end of its initialization:
  tail -f /var/log/cloud-init-output.log
EOF
  done < <(participants)
  echo "Access for lab $lab: $OUT_DIR/$lab/ (individual sheets + access.csv)"
}

access_nodes() {
  local lab=$1 id dir ips password sheet csv node ip
  mkdir -p "$OUT_DIR/$lab"
  csv="$OUT_DIR/$lab/access.csv"
  echo "participant;node;ip;password" >"$csv"
  while read -r id; do
    dir="$(env_dir "$id" "$lab")/nodes"
    ips=""
    [[ -d "$dir" ]] && ips=$(cd "$dir" && terragrunt output -json public_ips 2>/dev/null | jq -r 'to_entries[] | "\(.key) \(.value)"' || true)
    password=""
    [[ -n "$ips" ]] && password=$(cd "$dir" && terragrunt output -raw student_password 2>/dev/null || true)
    if [[ -z "$ips" || -z "$password" ]]; then
      warn "$lab: no access found for $id (environment not deployed?)"
      continue
    fi
    sheet="$OUT_DIR/$lab/$id.txt"
    {
      echo "CKS training (LFS460) - $id"
      echo
      while read -r node ip; do
        echo "$id;$node;$ip;$password" >>"$csv"
        printf 'Node %-7s: ssh student@%s\n' "$node" "$ip"
      done <<<"$ips"
      echo "Password : $password (the same for all your nodes, passwordless sudo)"
      echo
      echo "These machines are blank: follow the exercises of the course material."
      echo "Your instructor gives you the credentials to download the course files."
    } >"$sheet"
  done < <(participants)
  echo "Access for $lab: $OUT_DIR/$lab/ (individual sheets + access.csv)"
}

action=${1:-}
[[ -n "$action" ]] || usage
shift
# Validate the list here, in the main shell: a 'die' in a subshell would not stop the script.
[[ "$action" == _one ]] || participants >/dev/null
case "$action" in
  preflight) cmd_preflight "$@" ;;
  up) cmd_up "$@" ;;
  down) cmd_down "$@" ;;
  access) cmd_access "$@" ;;
  _one) cmd_one "$@" ;;
  *) usage ;;
esac
exit "${FAILED:-0}"
