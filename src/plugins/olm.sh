#!/usr/bin/env bash

# ~/.kind/plugin/olm.sh
# Installs/Status/Uninstalls Operator Lifecycle Manager (OLM)

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

OLM_VERSION="${OLM_VERSION:-v0.29.0}"
OLM_NS="${OLM_NS:-olm}"
OLM_TIMEOUT="${OLM_TIMEOUT:-300s}"

need() { command -v "$1" >/dev/null 2>&1 || { echo -e "${RED}❌ missing: $1${NC}"; return 1; }; }

olm_install() {
  need kubectl || return 1
  echo -e "${YELLOW}📦 Installing OLM ${OLM_VERSION}...${NC}"
  kubectl apply -f "https://github.com/operator-framework/operator-lifecycle-manager/releases/download/${OLM_VERSION}/crds.yaml"
  kubectl apply -f "https://github.com/operator-framework/operator-lifecycle-manager/releases/download/${OLM_VERSION}/olm.yaml"

  echo -e "${BLUE}⏳ Waiting for deployments...${NC}"
  for d in olm-operator catalog-operator packageserver; do
    kubectl -n "${OLM_NS}" rollout status deploy/"$d" --timeout="${OLM_TIMEOUT}" || true
  done

  echo -e "${BLUE}⏳ Waiting for PackageServer CSV to Succeeded...${NC}"
  # poll CSV phase
  end=$((SECONDS+600))
  while (( SECONDS < end )); do
    phase="$(kubectl -n "${OLM_NS}" get csv -o jsonpath='{range .items[?(@.metadata.name=="packageserver")]}{.status.phase}{end}' 2>/dev/null || true)"
    [[ "$phase" == "Succeeded" ]] && break
    sleep 3
  done

  kubectl -n "${OLM_NS}" get csv | grep -E 'packageserver' >/dev/null 2>&1 && \
    echo -e "${GREEN}✅ OLM ready.${NC}" || echo -e "${YELLOW}⚠️ OLM installed, CSV not confirmed. Check status.${NC}"
}

olm_uninstall() {
  need kubectl || return 1
  echo -e "${YELLOW}🧹 Uninstalling OLM ${OLM_VERSION}...${NC}"
  kubectl delete -f "https://github.com/operator-framework/operator-lifecycle-manager/releases/download/${OLM_VERSION}/olm.yaml" --ignore-not-found
  kubectl delete -f "https://github.com/operator-framework/operator-lifecycle-manager/releases/download/${OLM_VERSION}/crds.yaml" --ignore-not-found
  echo -e "${GREEN}✅ Uninstall requested.${NC}"
}

olm_status() {
  need kubectl || return 1
  if ! kubectl get ns "${OLM_NS}" >/dev/null 2>&1; then
    echo -e "${RED}❌ OLM not found (namespace '${OLM_NS}' missing).${NC}"
    return 1
  fi
  echo -e "${GREEN}✅ OLM namespace present.${NC}"
  echo -e "${BLUE}🔎 Deployments:${NC}"
  kubectl -n "${OLM_NS}" get deploy || true
  echo
  echo -e "${BLUE}📄 CSVs:${NC}"
  kubectl -n "${OLM_NS}" get csv || true
}

olm_help() {
  echo -e "${BOLD}${CYAN}olm.sh${NC}  (OLM ${OLM_VERSION})"
  echo "  install    Install/upgrade OLM"
  echo "  status     Show OLM status"
  echo "  uninstall  Remove OLM"
  echo "  help       Show this help"
  echo
  echo "Env: OLM_VERSION=${OLM_VERSION}  OLM_NS=${OLM_NS}  OLM_TIMEOUT=${OLM_TIMEOUT}"
}

# If sourced, export functions and return
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  export -f olm_install olm_uninstall olm_status olm_help
  return 0 2>/dev/null || true
fi

set -euo pipefail
case "${1:-install}" in
  install)   olm_install ;;
  status)    olm_status ;;
  uninstall) olm_uninstall ;;
  help|--help|-h) olm_help ;;
  *) echo -e "${RED}❌ unknown: $1${NC}"; olm_help; exit 1 ;;
esac
