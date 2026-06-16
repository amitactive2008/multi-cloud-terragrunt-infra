#!/usr/bin/env bash
# Deploy script for all Helmsman components in eci-prod / us-east-1 / prod
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/../../../account.env"
source "${SCRIPT_DIR}/../../region.env"
source "${SCRIPT_DIR}/env.env"

ACTION="--dry-run"
COMPONENT=""

for arg in "$@"; do
  case "$arg" in
    --apply)    ACTION="--apply" ;;
    --destroy)  ACTION="--destroy" ;;
    --dry-run)  ACTION="--dry-run" ;;
    monitoring|autoscaling|external-dns|ingress-controllers) COMPONENT="$arg" ;;
    *)          echo "Unknown argument: $arg"; exit 1 ;;
  esac
done

run_helmsman() {
  local component="$1"
  local component_dir="${SCRIPT_DIR}/${component}"
  echo ""
  echo "=============================="
  echo " Component: ${component}"
  echo " Action:    ${ACTION}"
  echo "=============================="
  if [[ -f "${component_dir}/.env" ]]; then
    # shellcheck disable=SC1090
    source "${component_dir}/.env"
  fi
  helmsman ${ACTION} -f "${component_dir}/dsf.yaml"
}

if [[ -n "${COMPONENT}" ]]; then
  run_helmsman "${COMPONENT}"
else
  run_helmsman "ingress-controllers"
  run_helmsman "monitoring"
  run_helmsman "autoscaling"
  run_helmsman "external-dns"
fi
