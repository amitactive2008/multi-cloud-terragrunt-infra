#!/usr/bin/env bash
# Deploy script for all Helmsman components in eci-dev / us-east-1 / dev
# Mirrors the role that `terragrunt run-all apply` plays in the Terragrunt world.
#
# Usage:
#   ./deploy.sh                              # plan all components (dry-run)
#   ./deploy.sh --apply                      # apply all components
#   ./deploy.sh --apply monitoring           # apply a single component
#   ./deploy.sh --destroy monitoring         # destroy a single component
#
# Prerequisites:
#   brew install helmsman
#   aws eks update-kubeconfig --region us-east-1 --name dev-eks

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── Load env vars from parent directories (mirrors find_in_parent_folders) ───
# shellcheck source=../../account.env
source "${SCRIPT_DIR}/../../account.env"
# shellcheck source=../region.env
source "${SCRIPT_DIR}/../region.env"
# shellcheck source=./env.env
source "${SCRIPT_DIR}/env.env"

# ─── Parse arguments ──────────────────────────────────────────────────────────
ACTION="--dry-run"
COMPONENT=""

for arg in "$@"; do
  case "$arg" in
    --apply)    ACTION="--apply" ;;
    --destroy)  ACTION="--destroy" ;;
    --dry-run)  ACTION="--dry-run" ;;
    common-devops-chart|monitoring|autoscaling|ingress-controllers|blackbox-exporter) COMPONENT="$arg" ;;
    *)          echo "Unknown argument: $arg"; exit 1 ;;
  esac
done

# ─── Helper ───────────────────────────────────────────────────────────────────
run_helmsman() {
  local component="$1"
  local component_dir="${SCRIPT_DIR}/${component}"
  local -a helmsman_args

  # Keep other Helmsman-managed releases when deploying a single component.
  helmsman_args=("${ACTION}" "-keep-untracked-releases")

  echo ""
  echo "=============================="
  echo " Component: ${component}"
  echo " Action:    ${ACTION}"
  echo "=============================="
  # Source component-level overrides (.env may not exist for all components)
  if [[ -f "${component_dir}/.env" ]]; then
    # shellcheck disable=SC1090
    source "${component_dir}/.env"
  fi

  # Run from component directory so relative values/charts paths resolve consistently.
  pushd "${component_dir}" >/dev/null
  helmsman "${helmsman_args[@]}" -f "dsf.yaml"
  popd >/dev/null

  # Monitoring post-step: manage internal ALB ingress in the same flow.
  if [[ "${component}" == "monitoring" ]]; then
    local ingress_manifest="${component_dir}/ingress-monitoring-alb.yaml"
    if [[ "${ACTION}" == "--apply" ]]; then
      echo "Applying internal ALB ingress for monitoring stack"
      kubectl apply -f "${ingress_manifest}"
    elif [[ "${ACTION}" == "--destroy" ]]; then
      echo "Deleting internal ALB ingress for monitoring stack"
      kubectl delete -f "${ingress_manifest}" --ignore-not-found=true
    else
      echo "Dry-run mode: internal ALB ingress step skipped (apply uses ${ingress_manifest})"
    fi
  fi
}

# ─── Run ──────────────────────────────────────────────────────────────────────
if [[ -n "${COMPONENT}" ]]; then
  run_helmsman "${COMPONENT}"
else
  # Ordered deployment (priority within each DSF handles intra-component order)
  run_helmsman "common-devops-chart"
  run_helmsman "ingress-controllers"
  run_helmsman "monitoring"
  run_helmsman "autoscaling"
fi
