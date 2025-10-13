#!/usr/bin/env bash

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

KEDA_NS="${KEDA_NS:-keda}"
KEDA_RELEASE="${KEDA_RELEASE:-keda}"
KEDA_CHART_REPO="${KEDA_CHART_REPO:-https://kedacore.github.io/charts}"
KEDA_CHART_NAME="${KEDA_CHART_NAME:-keda/keda}"
KEDA_CHART_VERSION="${KEDA_CHART_VERSION:-}"
KEDA_TIMEOUT="${KEDA_TIMEOUT:-300s}"
KEDA_DELETE_CRDS="${KEDA_DELETE_CRDS:-false}"

need(){ command -v "$1" >/dev/null 2>&1 || { echo -e "${RED}missing: $1${NC}"; return 1; }; }

keda_install(){
  need helm || return 1
  need kubectl || return 1
  helm repo add keda "${KEDA_CHART_REPO}" >/dev/null 2>&1 || true
  helm repo update >/dev/null 2>&1 || true
  kubectl get ns "${KEDA_NS}" >/dev/null 2>&1 || kubectl create ns "${KEDA_NS}" >/dev/null
  cat <<EOF | helm upgrade --install "${KEDA_RELEASE}" "${KEDA_CHART_NAME}" \
    --namespace "${KEDA_NS}" \
    --create-namespace \
    ${KEDA_CHART_VERSION:+--version "${KEDA_CHART_VERSION}"} \
    --atomic \
    -f - >/dev/null
# values pass-through if needed
EOF
  kubectl -n "${KEDA_NS}" rollout status deploy/keda-operator --timeout="${KEDA_TIMEOUT}" >/dev/null 2>&1 || true
  kubectl -n "${KEDA_NS}" rollout status deploy/keda-operator-metrics-apiserver --timeout="${KEDA_TIMEOUT}" >/dev/null 2>&1 || true
  echo -e "${GREEN}KEDA installed.${NC}"
}

keda_status(){
  need kubectl || return 1
  if ! kubectl get ns "${KEDA_NS}" >/dev/null 2>&1; then
    echo -e "${RED}namespace '${KEDA_NS}' not found.${NC}"; return 1
  fi
  kubectl -n "${KEDA_NS}" get deploy,po 2>/dev/null || true
  kubectl get crd scaledobjects.keda.sh triggerauthentications.keda.sh scaledjobs.keda.sh clustertriggerauthentications.keda.sh 2>/dev/null || true
}

keda_uninstall(){
  need helm || return 1
  need kubectl || return 1
  helm -n "${KEDA_NS}" uninstall "${KEDA_RELEASE}" >/dev/null 2>&1 || true
  if [[ "${KEDA_DELETE_CRDS}" == "true" ]]; then
    kubectl delete crd scaledobjects.keda.sh triggerauthentications.keda.sh scaledjobs.keda.sh clustertriggerauthentications.keda.sh --ignore-not-found >/dev/null 2>&1 || true
  fi
  echo -e "${GREEN}KEDA uninstall requested.${NC}"
}

keda_help(){
  echo -e "${BOLD}${CYAN}keda.sh${NC}"
  echo "  install     Install/upgrade KEDA"
  echo "  status      Show KEDA status"
  echo "  uninstall   Remove KEDA (set KEDA_DELETE_CRDS=true to drop CRDs)"
  echo "  help        Show this help"
  echo
  echo "Env: KEDA_NS=${KEDA_NS} KEDA_RELEASE=${KEDA_RELEASE} KEDA_CHART_VERSION=${KEDA_CHART_VERSION} KEDA_TIMEOUT=${KEDA_TIMEOUT} KEDA_DELETE_CRDS=${KEDA_DELETE_CRDS}"
}

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  export -f keda_install keda_status keda_uninstall keda_help
  return 0 2>/dev/null || true
fi

set -euo pipefail
case "${1:-install}" in
  install)   keda_install ;;
  status)    keda_status ;;
  uninstall) keda_uninstall ;;
  help|-h|--help) keda_help ;;
  *) echo -e "${RED}unknown: $1${NC}"; keda_help; exit 1 ;;
esac
