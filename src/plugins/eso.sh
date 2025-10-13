#!/usr/bin/env bash

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

ESO_VERSION="${ESO_VERSION:-0.10.4}"
ESO_NS="${ESO_NS:-external-secrets}"
ESO_TIMEOUT="${ESO_TIMEOUT:-180s}"

need() { command -v "$1" >/dev/null 2>&1 || { echo -e "${RED}❌ missing: $1${NC}"; return 1; }; }

eso_install() {
  need helm || return 1
  echo -e "${YELLOW}📦 Installing External Secrets Operator v${ESO_VERSION}...${NC}"

  helm repo add external-secrets https://charts.external-secrets.io >/dev/null 2>&1 || true
  helm repo update >/dev/null 2>&1 || true

  helm upgrade --install external-secrets external-secrets/external-secrets \
    -n "${ESO_NS}" \
    --version "${ESO_VERSION}" \
    --create-namespace \
    --wait \
    --timeout "${ESO_TIMEOUT}" \
    --set installCRDs=true

  echo -e "${GREEN}✅ External Secrets Operator installed successfully.${NC}"
}

eso_status() {
  kubectl get pods -n "${ESO_NS}" 2>/dev/null || echo -e "${YELLOW}ℹ️  Namespace ${ESO_NS} not found.${NC}"
}

eso_uninstall() {
  echo -e "${YELLOW}🧹 Uninstalling External Secrets Operator...${NC}"
  helm uninstall external-secrets -n "${ESO_NS}" >/dev/null 2>&1 || true
  echo -e "${GREEN}✅ External Secrets Operator uninstalled.${NC}"
}

case "$1" in
  install) eso_install ;;
  status) eso_status ;;
  uninstall|remove|delete) eso_uninstall ;;
  *)
    echo -e "${BOLD}External Secrets Operator Plugin${NC}"
    echo -e "${CYAN}Usage:${NC} $(basename "$0") {install|status|uninstall}"
    ;;
esac
