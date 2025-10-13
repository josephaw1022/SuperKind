#!/usr/bin/env bash

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

OLM_VERSION="${OLM_VERSION:-v0.34.0}"
OLM_NS="${OLM_NS:-olm}"
OLM_TIMEOUT="${OLM_TIMEOUT:-300s}"

need(){ command -v "$1" >/dev/null 2>&1 || { echo -e "${RED}❌ missing: $1${NC}"; return 1; }; }

_olm_quickstart_apply(){
  kubectl apply -f https://raw.githubusercontent.com/operator-framework/operator-lifecycle-manager/master/deploy/upstream/quickstart/crds.yaml
  kubectl apply -f https://raw.githubusercontent.com/operator-framework/operator-lifecycle-manager/master/deploy/upstream/quickstart/olm.yaml
}

_olm_quickstart_delete(){
  kubectl delete -f https://raw.githubusercontent.com/operator-framework/operator-lifecycle-manager/master/deploy/upstream/quickstart/olm.yaml --ignore-not-found
  kubectl delete -f https://raw.githubusercontent.com/operator-framework/operator-lifecycle-manager/master/deploy/upstream/quickstart/crds.yaml --ignore-not-found
}

olm_install(){
  need kubectl || return 1
  need curl || return 1
  echo -e "${YELLOW}Installing OLM ${OLM_VERSION}...${NC}"
  tmp="$(mktemp -d)"; pushd "$tmp" >/dev/null
  if curl -fsSL "https://github.com/operator-framework/operator-lifecycle-manager/releases/download/${OLM_VERSION}/install.sh" -o install.sh; then
    chmod +x install.sh
    ./install.sh "${OLM_VERSION}" || { echo -e "${YELLOW}Falling back to quickstart...${NC}"; _olm_quickstart_apply; }
  else
    echo -e "${YELLOW}Falling back to quickstart...${NC}"
    _olm_quickstart_apply
  fi
  popd >/dev/null

  echo -e "${BLUE}Waiting for deployments...${NC}"
  kubectl -n "${OLM_NS}" get deploy >/dev/null 2>&1 || kubectl create ns "${OLM_NS}" >/dev/null 2>&1 || true
  for d in $(kubectl -n "${OLM_NS}" get deploy -o name 2>/dev/null); do
    kubectl -n "${OLM_NS}" rollout status "$d" --timeout="${OLM_TIMEOUT}" || true
  done

  echo -e "${GREEN}OLM install done.${NC}"
}

olm_uninstall(){
  need kubectl || return 1
  echo -e "${YELLOW}Uninstalling OLM ${OLM_VERSION}...${NC}"
  tmp="$(mktemp -d)"; pushd "$tmp" >/dev/null
  if curl -fsSL "https://github.com/operator-framework/operator-lifecycle-manager/releases/download/${OLM_VERSION}/install.sh" -o install.sh; then
    chmod +x install.sh
    ./install.sh "${OLM_VERSION}" --delete || _olm_quickstart_delete
  else
    _olm_quickstart_delete
  fi
  popd >/dev/null
  echo -e "${GREEN}Uninstall requested.${NC}"
}

olm_status(){
  need kubectl || return 1
  if ! kubectl get ns "${OLM_NS}" >/dev/null 2>&1; then
    echo -e "${RED}OLM not found (namespace '${OLM_NS}' missing).${NC}"
    return 1
  fi
  echo -e "${GREEN}Namespace '${OLM_NS}' present.${NC}"
  kubectl -n "${OLM_NS}" get deploy || true
  kubectl -n "${OLM_NS}" get csv || true
}

olm_help(){
  echo -e "${BOLD}${CYAN}olm.sh${NC} (OLM ${OLM_VERSION})"
  echo "  install    Install/upgrade OLM"
  echo "  status     Show OLM status"
  echo "  uninstall  Remove OLM"
  echo "  help       Show this help"
  echo
  echo "Env: OLM_VERSION=${OLM_VERSION}  OLM_NS=${OLM_NS}  OLM_TIMEOUT=${OLM_TIMEOUT}"
}

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  export -f olm_install olm_uninstall olm_status olm_help
  return 0 2>/dev/null || true
fi

set -euo pipefail
case "${1:-install}" in
  install)   olm_install ;;
  status)    olm_status ;;
  uninstall) olm_uninstall ;;
  help|-h|--help) olm_help ;;
  *) echo -e "${RED}unknown: $1${NC}"; olm_help; exit 1 ;;
esac
