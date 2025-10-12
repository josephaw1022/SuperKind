#!/usr/bin/env bash

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# ---- Config (override with env) ----
EPINIO_NS="${EPINIO_NS:-epinio}"
EPINIO_DOMAIN="${EPINIO_DOMAIN:-127.0.0.1.sslip.io}"
EPINIO_ISSUER="${EPINIO_ISSUER:-quick-kind-ca}"
EPINIO_TIMEOUT="${EPINIO_TIMEOUT:-300s}"
# Optional: pin chart version, e.g., EPINIO_CHART_VERSION="1.13.0"
EPINIO_CHART_VERSION="${EPINIO_CHART_VERSION:-}"

need() { command -v "$1" >/dev/null 2>&1 || { echo -e "${RED}❌ missing: $1${NC}"; return 1; }; }

epinio_install() {
  need kubectl || return 1
  need helm || return 1

  echo -e "${YELLOW}📦 Installing/Upgrading Epinio in namespace '${EPINIO_NS}'...${NC}"
  helm repo add epinio https://epinio.github.io/helm-charts >/dev/null 2>&1 || true
  helm repo update >/dev/null 2>&1 || true

  local verFlag=()
  [[ -n "$EPINIO_CHART_VERSION" ]] && verFlag=(--version "$EPINIO_CHART_VERSION")

  cat <<EOF | helm upgrade --install epinio epinio/epinio \
    --namespace "${EPINIO_NS}" \
    --create-namespace \
    "${verFlag[@]}" \
    --values -
global:
  domain: ${EPINIO_DOMAIN}
ingress:
  annotations:
    cert-manager.io/cluster-issuer: ${EPINIO_ISSUER}
EOF

  echo -e "${BLUE}⏳ Waiting for Epinio pods to be Ready (${EPINIO_TIMEOUT})...${NC}"
  kubectl -n "${EPINIO_NS}" wait --for=condition=Ready pods --all --timeout="${EPINIO_TIMEOUT}" || true

  echo -e "${GREEN}✅ Epinio install/upgrade complete.${NC}"
  echo -e "${CYAN}🌐 Access:${NC} https://epinio.${EPINIO_DOMAIN}"
}

epinio_status() {
  need kubectl || return 1
  if ! kubectl get ns "${EPINIO_NS}" >/dev/null 2>&1; then
    echo -e "${RED}❌ Namespace '${EPINIO_NS}' not found. Epinio not installed?${NC}"
    return 1
  fi

  echo -e "${GREEN}✅ Namespace '${EPINIO_NS}' present.${NC}"
  echo -e "${BLUE}🔎 Deployments:${NC}"
  kubectl -n "${EPINIO_NS}" get deploy || true
  echo
  echo -e "${BLUE}📦 Pods:${NC}"
  kubectl -n "${EPINIO_NS}" get pods -o wide || true
  echo
  echo -e "${BLUE}🌐 Services & Ingress:${NC}"
  kubectl -n "${EPINIO_NS}" get svc,ingress || true
  echo
  echo -e "${CYAN}🌍 Expected URL:${NC} https://epinio.${EPINIO_DOMAIN}"
}

epinio_uninstall() {
  need helm || return 1
  need kubectl || return 1

  echo -e "${YELLOW}🧹 Uninstalling Epinio release 'epinio' from '${EPINIO_NS}'...${NC}"
  helm -n "${EPINIO_NS}" uninstall epinio --wait --timeout "${EPINIO_TIMEOUT}" >/dev/null 2>&1 || true

  # Leave the namespace for manual inspection; delete if empty.
  if kubectl get ns "${EPINIO_NS}" >/dev/null 2>&1; then
    # best-effort cleanup when there is nothing left
    kubectl -n "${EPINIO_NS}" delete all --all >/dev/null 2>&1 || true
    echo -e "${CYAN}ℹ️ Namespace '${EPINIO_NS}' retained. Delete manually if desired: kubectl delete ns ${EPINIO_NS}${NC}"
  fi

  echo -e "${GREEN}✅ Uninstall requested.${NC}"
}

epinio_help() {
  echo -e "${BOLD}${CYAN}epinio.sh${NC}"
  echo "  install     Install/upgrade Epinio via Helm"
  echo "  status      Show Epinio resources in the namespace"
  echo "  uninstall   Remove the Helm release (namespace retained)"
  echo "  help        Show this help"
  echo
  echo "Env:"
  echo "  EPINIO_NS=${EPINIO_NS}"
  echo "  EPINIO_DOMAIN=${EPINIO_DOMAIN}"
  echo "  EPINIO_ISSUER=${EPINIO_ISSUER}"
  echo "  EPINIO_TIMEOUT=${EPINIO_TIMEOUT}"
  echo "  EPINIO_CHART_VERSION=${EPINIO_CHART_VERSION:-<unset>}"
}

# If sourced, export functions and return (so you can call epinio_install etc.)
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  export -f epinio_install epinio_status epinio_uninstall epinio_help
  return 0 2>/dev/null || true
fi

# Executed directly
set -euo pipefail
case "${1:-install}" in
  install)    epinio_install ;;
  status)     epinio_status ;;
  uninstall)  epinio_uninstall ;;
  help|-h|--help) epinio_help ;;
  *) echo -e "${RED}❌ unknown: $1${NC}"; epinio_help; exit 1 ;;
esac
