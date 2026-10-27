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
# Configuration : training/classroom.env (copier classroom.env.example).
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
TRAINING_DIR="$ROOT/training"
CONF=${CKS_CLASSROOM_CONF:-$TRAINING_DIR/classroom.env}
# shellcheck disable=SC1090
[[ -f "$CONF" ]] && . "$CONF"

PARTICIPANTS_FILE=${PARTICIPANTS_FILE:-$TRAINING_DIR/participants.txt}
PARALLEL=${PARALLEL:-4}
CKS_REPO_REF=${CKS_REPO_REF:-master}
OUT_DIR="$TRAINING_DIR/out"
LOG_DIR="$TRAINING_DIR/logs"
UPSTREAM_REPO="ViktorUJ/cks"
UPSTREAM_BUCKET="sre-learning-platform-state-backet"
export CKS_REPO CKS_REPO_REF
[[ -n "${CKS_ACCESS_CIDRS:-}" ]] && export CKS_ACCESS_CIDRS

die() { echo "ERREUR : $*" >&2; exit 1; }
warn() { echo "ATTENTION : $*" >&2; }

usage() {
  sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
  exit 1
}

participants() {
  [[ -f "$PARTICIPANTS_FILE" ]] || die "liste des participants introuvable : $PARTICIPANTS_FILE"
  local id
  grep -vE '^[[:space:]]*(#|$)' "$PARTICIPANTS_FILE" | tr -d ' \r' | while read -r id; do
    # L'identifiant finit dans des noms de ressources AWS et des chemins S3.
    [[ "$id" =~ ^[a-z0-9][a-z0-9-]{0,19}$ ]] || die "identifiant invalide '$id' (a-z, 0-9, '-', 20 caractères max)"
    echo "$id"
  done
}

# Les VMs vierges LFS460 ne passent pas par le Makefile, qui ne connaît que tasks/cks/labs.
is_nodes() { [[ "$1" == lfs460-* ]]; }

stack_dir() {
  if is_nodes "$1"; then echo "$ROOT/tasks/cks/lfs460/${1#lfs460-}"; else echo "$ROOT/tasks/cks/labs/$1"; fi
}

check_lab() {
  [[ "$1" =~ ^([0-9]{3}|lfs460-(single|cluster))$ && -f "$(stack_dir "$1")/env.hcl" ]] ||
    die "lab inconnu : $1 (attendu : 101 à 115, lfs460-single ou lfs460-cluster)"
}

env_dir() {
  if is_nodes "$2"; then echo "$ROOT/terraform/environments/${1}_${2}"; else echo "$ROOT/terraform/environments/${1}_${2}_cks-labs"; fi
}

lab_region() { grep -E '^\s*region\s*=' "$(stack_dir "$1")/env.hcl" | head -1 | awk -F'"' '{print $2}'; }

# Nombre d'instances EC2 d'un lab, toutes à 2 vCPU (t3) : une VM par référence à un type d'instance,
# ou par nœud déclaré pour les VMs LFS460.
lab_instances() {
  if is_nodes "$1"; then
    grep -E '^\s*nodes\s*=' "$(stack_dir "$1")/env.hcl" | grep -o '"[a-z]*"' | wc -l | tr -d ' '
  else
    grep -hoE 'instance_type[a-z_]* *= *local\.vars\.locals\.instance_type' "$(stack_dir "$1")"/*/terragrunt.hcl | wc -l | tr -d ' '
  fi
}

quota() {
  aws service-quotas get-service-quota --region "$1" --service-code "$2" --quota-code "$3" \
    --query 'Quota.Value' --output text 2>/dev/null | cut -d. -f1
}

cmd_preflight() {
  local errors=0 tool lab
  for tool in make terraform terragrunt aws jq curl; do
    command -v "$tool" >/dev/null || { echo "  - outil manquant : $tool"; errors=$((errors + 1)); }
  done
  ((errors == 0)) || die "installez les outils manquants (terragrunt : v0.73.x, comme dans docker/runner)"

  local arn
  arn=$(aws sts get-caller-identity --query Arn --output text) || die "pas d'accès AWS (aws configure / AWS_PROFILE)"
  echo "AWS : $arn"

  local bucket
  bucket=$(grep '^  backend_bucket' "$ROOT/terraform/environments/terragrunt.hcl" | awk -F'"' '{print $2}')
  if [[ "$bucket" == "$UPSTREAM_BUCKET" ]]; then
    echo "  - backend_bucket est celui du projet amont : mettez votre propre nom dans terraform/environments/terragrunt.hcl"
    errors=$((errors + 1))
  else
    echo "State Terraform : s3://$bucket"
  fi

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
    local region vpcs=0 vcpus=0 used_vpcs vpc_quota vcpu_quota
    for lab in "$@"; do
      check_lab "$lab"
      region=$(lab_region "$lab")
      vpcs=$((vpcs + n))
      vcpus=$((vcpus + n * 2 * $(lab_instances "$lab")))
    done
    # Tous les labs CKS sont dans la même région : on raisonne sur la dernière lue.
    used_vpcs=$(aws ec2 describe-vpcs --region "$region" --query 'length(Vpcs)' --output text)
    vpc_quota=$(quota "$region" vpc L-F678F1CE)
    vcpu_quota=$(quota "$region" ec2 L-1216C47A)
    echo "Région $region : besoin estimé $vpcs VPC (existants : $used_vpcs, quota : ${vpc_quota:-?}), $vcpus vCPU on-demand (quota : ${vcpu_quota:-?})"
    if [[ -n "$vpc_quota" ]] && ((used_vpcs + vpcs > vpc_quota)); then
      echo "  - quota VPC insuffisant : demandez une augmentation (Service Quotas > Amazon VPC > VPCs per Region)"
      errors=$((errors + 1))
    fi
    if [[ -n "$vcpu_quota" ]] && ((vcpus > vcpu_quota)); then
      echo "  - quota vCPU insuffisant : demandez une augmentation (Service Quotas > EC2 > Running On-Demand Standard instances)"
      errors=$((errors + 1))
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
  if is_nodes "$lab"; then
    run_nodes "$action" "$lab" "$id" >"$log" 2>&1 </dev/null && status=OK || status=ECHEC
  elif (cd "$ROOT" && USER_ID="$id" ENV_ID="$lab" TASK="$lab" make "${action}_cks_task") >"$log" 2>&1 </dev/null; then
    status=OK
  else
    status=ECHEC
  fi
  echo "$status" >"$LOG_DIR/$lab/$id.$action.status"
  echo "[$lab] $id : $action $status"
}

# Équivalent du Makefile pour les VMs LFS460 : copie de la stack sous terraform/environments
# (où se trouve la configuration racine de terragrunt), puis apply ou destroy.
run_nodes() {
  local action=$1 lab=$2 id=$3 dir
  dir=$(env_dir "$id" "$lab")
  mkdir -p "$dir"
  cp -r "$(stack_dir "$lab")"/* "$dir"
  export TF_VAR_USER_ID="$id" TF_VAR_ENV_ID="$lab"
  case "$action" in
    run) (cd "$dir" && terragrunt run-all apply) ;;
    delete) (cd "$dir" && terragrunt run-all destroy) && rm -rf "$dir" ;;
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
