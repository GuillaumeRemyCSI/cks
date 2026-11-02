#!/usr/bin/env bash
# Déploiement des labs CKS pour une classe : un environnement isolé par participant.
# Repose sur le mécanisme USER_ID / ENV_ID du Makefile (voir docs/multiple_users_envs.MD).
#
#   training/classroom.sh preflight 107
#   training/classroom.sh up 107 108
#   training/classroom.sh access 107
#   training/classroom.sh down 107 108
#
# VMs vierges des exercices officiels LFS460 (Ubuntu 24.04, 2 vCPU / 8 Go, utilisateur student) :
#   training/classroom.sh up lfs460-single     nœud 'single' (chapitres 2-3)
#   training/classroom.sh up lfs460-cluster    nœuds 'cp' et 'worker' (chapitre 4 et suivants)
#
# Cloud : AWS par défaut, Google Cloud avec CKS_CLOUD=gcp (voir training/README.md).
# Configuration : training/classroom.env (copier classroom.env.example).
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
TRAINING_DIR="$ROOT/training"
CONF=${CKS_CLASSROOM_CONF:-$TRAINING_DIR/classroom.env}
# Les variables passées sur la ligne de commande (PARTICIPANTS_FILE=... classroom.sh up 107)
# priment sur classroom.env.
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
[[ "$CKS_CLOUD" == aws || "$CKS_CLOUD" == gcp ]] || { echo "ERREUR : CKS_CLOUD doit valoir aws ou gcp" >&2; exit 1; }
export CKS_REPO CKS_REPO_REF CKS_CLOUD CKS_GCP_PROJECT CKS_GCP_STATE_BUCKET CKS_GCP_REGION CKS_GCP_ZONE
# gcloud pose des questions (activer une API, etc.) que personne ne verrait : il doit échouer à la place.
export CLOUDSDK_CORE_DISABLE_PROMPTS=1

# CIDR IPv4 uniquement (les VMs n'ont pas d'IPv6) ; une adresse seule devient un /32.
if [[ -n "${CKS_ACCESS_CIDRS:-}" ]]; then
  cidrs=""
  IFS=',' read -ra parts <<<"${CKS_ACCESS_CIDRS// /}"
  for cidr in "${parts[@]}"; do
    if [[ "$cidr" == *:* ]]; then
      echo "ERREUR : CKS_ACCESS_CIDRS : $cidr est une adresse IPv6, or les VMs n'ont que de l'IPv4 (votre IPv4 : curl -4 -s ifconfig.me)" >&2
      exit 1
    fi
    [[ "$cidr" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}(/[0-9]{1,2})?$ ]] || { echo "ERREUR : CKS_ACCESS_CIDRS : '$cidr' n'est pas un CIDR IPv4" >&2; exit 1; }
    [[ "$cidr" == */* ]] || cidr="$cidr/32"
    cidrs+="${cidrs:+,}$cidr"
  done
  export CKS_ACCESS_CIDRS=$cidrs
fi

die() { echo "ERREUR : $*" >&2; exit 1; }
warn() { echo "ATTENTION : $*" >&2; }

usage() {
  sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
  exit 1
}

participants() {
  [[ -f "$PARTICIPANTS_FILE" ]] || die "liste des participants introuvable : $PARTICIPANTS_FILE"
  local id
  grep -vE '^[[:space:]]*(#|$)' "$PARTICIPANTS_FILE" | tr -d ' \r' | while read -r id; do
    # L'identifiant finit dans des noms de ressources cloud et des chemins de state.
    [[ "$id" =~ ^[a-z0-9][a-z0-9-]{0,19}$ ]] || die "identifiant invalide '$id' (a-z, 0-9, '-', 20 caractères max)"
    echo "$id"
  done
}

# Les VMs vierges LFS460 ne passent pas par le Makefile, qui ne connaît que tasks/cks/labs.
is_nodes() { [[ "$1" == lfs460-* ]]; }

# Le Makefile ne gère que les labs sur AWS : le reste est déployé par run_stack.
uses_make() { [[ "$CKS_CLOUD" == aws ]] && ! is_nodes "$1"; }

# Chaque cloud a sa configuration racine terragrunt (state S3 ou GCS), trouvée en remontant l'arborescence.
env_root() { if [[ "$CKS_CLOUD" == gcp ]]; then echo "$ROOT/terraform/environments-gcp"; else echo "$ROOT/terraform/environments"; fi; }

stack_dir() {
  if is_nodes "$1"; then echo "$ROOT/tasks/cks/lfs460/${1#lfs460-}"; else echo "$ROOT/tasks/cks/labs/$1"; fi
}

check_lab() {
  [[ "$1" =~ ^([0-9]{3}|lfs460-(single|cluster))$ && -f "$(stack_dir "$1")/env.hcl" ]] ||
    die "lab inconnu : $1 (attendu : 101 à 115, lfs460-single ou lfs460-cluster)"
}

env_dir() {
  if uses_make "$2"; then echo "$(env_root)/${1}_${2}_cks-labs"; else echo "$(env_root)/${1}_${2}"; fi
}

lab_region() {
  if [[ "$CKS_CLOUD" == gcp ]]; then echo "$CKS_GCP_REGION"; return; fi
  grep -E '^\s*region\s*=' "$(stack_dir "$1")/env.hcl" | head -1 | awk -F'"' '{print $2}'
}

# Règles de pare-feu GCP d'un lab : une pour le réseau, plus une par groupe de VMs.
lab_firewalls() {
  local dir count=1
  for dir in "$(stack_dir "$1")"/*/; do
    case "$(basename "$dir")" in k8s-* | worker | docker-host | nodes) count=$((count + 1)) ;; esac
  done
  echo "$count"
}

# Nombre d'instances EC2 d'un lab, toutes à 2 vCPU (t3) : une VM par référence à un type d'instance,
# ou par nœud déclaré pour les VMs LFS460.
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

# "<limite> <utilisé>" d'un quota GCP, régional (CPUS, IN_USE_ADDRESSES) ou du projet (NETWORKS, FIREWALLS).
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
  arn=$(aws sts get-caller-identity --query Arn --output text) || die "pas d'accès AWS (aws configure / AWS_PROFILE)"
  echo "AWS : $arn"
  bucket=$(grep '^  backend_bucket' "$ROOT/terraform/environments/terragrunt.hcl" | awk -F'"' '{print $2}')
  if [[ "$bucket" == "$UPSTREAM_BUCKET" ]]; then
    echo "  - backend_bucket est celui du projet amont : mettez votre propre nom dans terraform/environments/terragrunt.hcl"
    errors=$((errors + 1))
  else
    echo "State Terraform : s3://$bucket"
  fi
}

preflight_gcp() {
  [[ -n "${CKS_GCP_PROJECT:-}" ]] || die "CKS_GCP_PROJECT n'est pas défini (training/classroom.env)"
  [[ -n "${CKS_GCP_STATE_BUCKET:-}" ]] || die "CKS_GCP_STATE_BUCKET n'est pas défini (training/classroom.env)"
  gcloud auth application-default print-access-token >/dev/null 2>&1 ||
    die "pas d'identifiants pour Terraform : gcloud auth application-default login"
  gcloud projects describe "$CKS_GCP_PROJECT" --format='value(projectId)' >/dev/null 2>&1 ||
    die "projet GCP inaccessible : $CKS_GCP_PROJECT"
  echo "Google Cloud : projet $CKS_GCP_PROJECT, $CKS_GCP_REGION / $CKS_GCP_ZONE"
  [[ -n "$(gcloud services list --enabled --project "$CKS_GCP_PROJECT" \
    --filter="config.name=compute.googleapis.com" --format='value(config.name)' 2>/dev/null)" ]] ||
    die "API Compute Engine désactivée : gcloud services enable compute.googleapis.com --project $CKS_GCP_PROJECT"
  if gcloud storage buckets describe "gs://$CKS_GCP_STATE_BUCKET" --project "$CKS_GCP_PROJECT" >/dev/null 2>&1; then
    echo "State Terraform : gs://$CKS_GCP_STATE_BUCKET"
  else
    echo "State Terraform : gs://$CKS_GCP_STATE_BUCKET (sera créé par terragrunt)"
  fi
}

# Compare un besoin à ce qui reste d'un quota : check_need <libellé> <besoin> <limite> <utilisé>.
# Une limite vide (quota illisible) est signalée sans bloquer.
check_need() {
  local label=$1 need=$2 limit=${3:-} used=${4:-0}
  if [[ -z "$limit" ]]; then
    echo "  $label : besoin $need, quota inconnu (vérifiez-le dans la console)"
    return
  fi
  echo "  $label : besoin $need, disponible $((limit - used)) (quota $limit)"
  if ((need > limit - used)); then
    echo "  - quota insuffisant : $label (demandez une augmentation dans la console)"
    errors=$((errors + 1))
  fi
}

cmd_preflight() {
  local errors=0 tool lab
  local tools="terraform terragrunt jq curl"
  if [[ "$CKS_CLOUD" == gcp ]]; then tools+=" gcloud"; else tools+=" make aws"; fi
  for tool in $tools; do
    command -v "$tool" >/dev/null || { echo "  - outil manquant : $tool"; errors=$((errors + 1)); }
  done
  ((errors == 0)) || die "installez les outils manquants (terragrunt : v0.73.x, comme dans docker/runner)"

  "preflight_$CKS_CLOUD"

  # Les VMs LFS460 ne téléchargent rien depuis le fork : la vérification ne concerne que les labs 101-115.
  local needs_repo=$(($# == 0))
  for lab in "$@"; do is_nodes "$lab" || needs_repo=1; done
  if ((needs_repo == 0)); then
    :
  elif [[ -z "${CKS_REPO:-}" || "$CKS_REPO" == "$UPSTREAM_REPO" ]]; then
    echo "  - CKS_REPO doit pointer sur votre fork : les VMs y téléchargent les scripts et tests adaptés (K8s 1.35)"
    errors=$((errors + 1))
  else
    local raw="https://raw.githubusercontent.com/$CKS_REPO/$CKS_REPO_REF/tasks/cks/labs/101/env.hcl"
    if curl -fsSL "$raw" 2>/dev/null | grep -q 'k8_version = "1.35.2"'; then
      echo "Dépôt des scripts : $CKS_REPO@$CKS_REPO_REF (adaptations présentes)"
    else
      echo "  - $raw n'est pas accessible ou ne contient pas les adaptations : poussez la branche $CKS_REPO_REF (dépôt public)"
      errors=$((errors + 1))
    fi
  fi

  echo "Accès SSH autorisé depuis : ${CKS_ACCESS_CIDRS:-0.0.0.0/0 (tout Internet)}"

  local n
  n=$(participants | wc -l | tr -d ' ')
  ((n > 0)) || die "aucun participant dans $PARTICIPANTS_FILE"
  echo "Participants : $n"

  if (($# > 0)); then
    local region networks=0 vms=0 firewalls=0
    for lab in "$@"; do
      check_lab "$lab"
      region=$(lab_region "$lab")
      networks=$((networks + n))
      vms=$((vms + n * $(lab_instances "$lab")))
      firewalls=$((firewalls + n * $(lab_firewalls "$lab")))
    done
    # Tous les labs sont dans la même région ; toutes les VMs ont 2 vCPU.
    echo "Quotas ($region) :"
    if [[ "$CKS_CLOUD" == gcp ]]; then
      # shellcheck disable=SC2046 # gcp_quota renvoie "<limite> <utilisé>"
      check_need "réseaux VPC (projet)" "$networks" $(gcp_quota project NETWORKS)
      # shellcheck disable=SC2046
      check_need "règles de pare-feu (projet)" "$firewalls" $(gcp_quota project FIREWALLS)
      # shellcheck disable=SC2046
      check_need "vCPU" "$((vms * 2))" $(gcp_quota "$region" CPUS)
      # shellcheck disable=SC2046
      check_need "IP externes" "$vms" $(gcp_quota "$region" IN_USE_ADDRESSES)
    else
      local used_vpcs
      used_vpcs=$(aws ec2 describe-vpcs --region "$region" --query 'length(Vpcs)' --output text)
      check_need "VPC" "$networks" "$(aws_quota "$region" vpc L-F678F1CE)" "$used_vpcs"
      check_need "vCPU on-demand" "$((vms * 2))" "$(aws_quota "$region" ec2 L-1216C47A)" 0
    fi
  fi

  ((errors == 0)) || die "$errors point(s) bloquant(s)"
  echo "Preflight OK"
}

# Exécuté en parallèle par xargs, une fois par participant.
cmd_one() {
  local action=$1 lab=$2 id=$3 log status
  mkdir -p "$LOG_DIR/$lab"
  log="$LOG_DIR/$lab/$id.$action.log"
  # Sans terminal, la confirmation de 'terragrunt run-all' échouerait.
  export TERRAGRUNT_NON_INTERACTIVE=true TG_NON_INTERACTIVE=true
  if ! uses_make "$lab"; then
    run_stack "$action" "$lab" "$id" >"$log" 2>&1 </dev/null && status=OK || status=ECHEC
  elif (cd "$ROOT" && USER_ID="$id" ENV_ID="$lab" TASK="$lab" make "${action}_cks_task") >"$log" 2>&1 </dev/null; then
    status=OK
  else
    status=ECHEC
  fi
  echo "$status" >"$LOG_DIR/$lab/$id.$action.status"
  echo "[$lab] $id : $action $status"
}

# Équivalent du Makefile (VMs LFS460, labs sur GCP) : copie de la stack sous la racine terragrunt
# du cloud choisi, puis apply ou destroy.
run_stack() {
  local action=$1 lab=$2 id=$3 dir
  dir=$(env_dir "$id" "$lab")
  mkdir -p "$dir"
  cp -r "$(stack_dir "$lab")"/* "$dir"
  export TF_VAR_USER_ID="$id" TF_VAR_ENV_ID="$lab"
  # terragrunt 1.x a remplacé run-all (version 0.73 du repo) par run --all.
  local all="run-all"
  terragrunt run --help 2>/dev/null | grep -q -- '--all' && all="run --all"
  case "$action" in
    # shellcheck disable=SC2086 # $all contient la sous-commande et son option
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
    echo "== Lab $lab : $action pour $(participants | wc -l | tr -d ' ') participant(s), $PARALLEL en parallèle"
    participants | xargs -P "$PARALLEL" -I{} "$BASH" "$0" _one "$action" "$lab" {}
    failed=$(participants | while read -r id; do
      [[ "$(cat "$LOG_DIR/$lab/$id.$action.status" 2>/dev/null)" == OK ]] || echo "$id"
    done)
    if [[ -n "$failed" ]]; then
      warn "lab $lab, $action en échec pour : $(echo $failed) (logs : $LOG_DIR/$lab/<id>.$action.log)"
      FAILED=1
    fi
  done
}

cmd_up() {
  (($# > 0)) || usage
  cmd_preflight "$@"
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
  csv="$OUT_DIR/$lab/acces.csv"
  echo "participant;ip;mot_de_passe" >"$csv"
  while read -r id; do
    dir="$(env_dir "$id" "$lab")/worker"
    ssh=""
    [[ -d "$dir" ]] && ssh=$(cd "$dir" && terragrunt output -raw worker_pc_ssh 2>/dev/null | grep -oE 'ssh ubuntu@[0-9.]+ password= [^ ]+' || true)
    if [[ -z "$ssh" ]]; then
      warn "lab $lab : pas d'accès trouvé pour $id (environnement non déployé ?)"
      continue
    fi
    ip=$(echo "$ssh" | sed -E 's/ssh ubuntu@([0-9.]+).*/\1/')
    password=$(echo "$ssh" | sed -E 's/.*password= //')
    echo "$id;$ip;$password" >>"$csv"
    sheet="$OUT_DIR/$lab/$id.txt"
    cat >"$sheet" <<EOF
Formation CKS - lab $lab - $id

Énoncé    : https://github.com/${CKS_REPO:-$UPSTREAM_REPO}/blob/$CKS_REPO_REF/tasks/cks/labs/$lab/README_FR.MD
Connexion : ssh ubuntu@$ip
Mot de passe : $password

Sur le poste de travail :
  time_left      temps restant
  check_result   vérifie vos réponses et donne le score
Si la machine vient de démarrer, attendez la fin de l'initialisation :
  tail -f /var/log/cloud-init-output.log
EOF
  done < <(participants)
  echo "Accès du lab $lab : $OUT_DIR/$lab/ (fiches individuelles + acces.csv)"
}

access_nodes() {
  local lab=$1 id dir ips password sheet csv node ip
  mkdir -p "$OUT_DIR/$lab"
  csv="$OUT_DIR/$lab/acces.csv"
  echo "participant;noeud;ip;mot_de_passe" >"$csv"
  while read -r id; do
    dir="$(env_dir "$id" "$lab")/nodes"
    ips=""
    [[ -d "$dir" ]] && ips=$(cd "$dir" && terragrunt output -json public_ips 2>/dev/null | jq -r 'to_entries[] | "\(.key) \(.value)"' || true)
    password=""
    [[ -n "$ips" ]] && password=$(cd "$dir" && terragrunt output -raw student_password 2>/dev/null || true)
    if [[ -z "$ips" || -z "$password" ]]; then
      warn "$lab : pas d'accès trouvé pour $id (environnement non déployé ?)"
      continue
    fi
    sheet="$OUT_DIR/$lab/$id.txt"
    {
      echo "Formation CKS (LFS460) - $id"
      echo
      while read -r node ip; do
        echo "$id;$node;$ip;$password" >>"$csv"
        printf 'Nœud %-7s: ssh student@%s\n' "$node" "$ip"
      done <<<"$ips"
      echo "Mot de passe : $password (le même pour tous vos nœuds, sudo sans mot de passe)"
      echo
      echo "Ces machines sont vierges : suivez les exercices du support de cours."
      echo "Les identifiants de téléchargement des fichiers du cours vous sont donnés par le formateur."
    } >"$sheet"
  done < <(participants)
  echo "Accès $lab : $OUT_DIR/$lab/ (fiches individuelles + acces.csv)"
}

action=${1:-}
[[ -n "$action" ]] || usage
shift
# Valide la liste ici, dans le shell principal : un 'die' dans un sous-shell n'arrêterait pas le script.
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
