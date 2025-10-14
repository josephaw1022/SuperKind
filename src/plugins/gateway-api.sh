#!/usr/bin/env bash

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# ---- Config (override via env) ----
GW_NS="${GW_NS:-kube-system}"
GW_RELEASE="${GW_RELEASE:-my-gateway-api}"
GW_CHART_REPO="${GW_CHART_REPO:-https://charts.appscode.com/stable/}"
GW_CHART_NAME="${GW_CHART_NAME:-appscode/gateway-api}"
GW_CHART_VERSION="${GW_CHART_VERSION:-2025.9.19}"
GW_TIMEOUT="${GW_TIMEOUT:-300s}"

need(){ command -v "$1" >/dev/null 2>&1 || { echo -e "${RED}❌ missing: $1${NC}"; return 1; }; }

gateway_install(){
  need helm || return 1
  need kubectl || return 1

  echo -e "${YELLOW}📦 Adding and updating Helm repo 'appscode'...${NC}"
  helm repo add appscode "${GW_CHART_REPO}" >/dev/null 2>&1 || true
  helm repo update >/dev/null 2>&1 || true

  echo -e "${YELLOW}🚀 Installing Gateway API (${GW_RELEASE}) into ${GW_NS}...${NC}"
  helm upgrade --install "${GW_RELEASE}" "${GW_CHART_NAME}" \
    --namespace "${GW_NS}" \
    --create-namespace \
    --version "${GW_CHART_VERSION}" \
    --atomic >/dev/null

  echo -e "${BLUE}⏳ Waiting for Gateway CRDs to register...${NC}"
  kubectl get crd | grep -E 'gateway.networking.k8s.io|httproute.networking.k8s.io|tcproute.networking.k8s.io' >/dev/null 2>&1 || sleep 5

  echo -e "${GREEN}✅ Gateway API installed successfully in '${GW_NS}'.${NC}"
}

gateway_status(){
  need kubectl || return 1
  echo -e "${BLUE}🔎 Gateway API resources in '${GW_NS}':${NC}"
  kubectl -n "${GW_NS}" get all -l "app.kubernetes.io/instance=${GW_RELEASE}" 2>/dev/null || true
  echo
  echo -e "${BLUE}📦 Installed CRDs:${NC}"
  kubectl get crd | grep -E 'gateway.networking.k8s.io|httproute.networking.k8s.io|tcproute.networking.k8s.io|tlsroute.networking.k8s.io' || true
}

gateway_uninstall(){
  need helm || return 1
  echo -e "${YELLOW}🧹 Uninstalling Gateway API release '${GW_RELEASE}'...${NC}"
  helm -n "${GW_NS}" uninstall "${GW_RELEASE}" >/dev/null 2>&1 || true
  echo -e "${CYAN}ℹ️ Namespace '${GW_NS}' retained. Delete manually if desired.${NC}"
  echo -e "${GREEN}✅ Uninstall requested.${NC}"
}

gateway_help(){
  echo -e "${BOLD}${CYAN}gateway.sh${NC}"
  echo "  install     Install Gateway API CRDs from Appscode chart"
  echo "  status      Show Gateway API components and CRDs"
  echo "  uninstall   Remove the Helm release (namespace retained)"
  echo "  help        Show this help"
  echo
  echo "Env:"
  echo "  GW_NS=${GW_NS}  GW_RELEASE=${GW_RELEASE}  GW_CHART_VERSION=${GW_CHART_VERSION}  GW_TIMEOUT=${GW_TIMEOUT}"
}

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  export -f gateway_install gateway_status gateway_uninstall gateway_help
  return 0 2>/dev/null || true
fi

set -euo pipefail
case "${1:-install}" in
  install)    gateway_install ;;
  status)     gateway_status ;;
  uninstall)  gateway_uninstall ;;
  help|-h|--help) gateway_help ;;
  *) echo -e "${RED}❌ unknown: $1${NC}"; gateway_help; exit 1 ;;
esac
