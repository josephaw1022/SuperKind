#!/usr/bin/env bash

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# ---- Config (override via env) ----
ARGOCD_NS="${ARGOCD_NS:-argocd}"
ARGOCD_RELEASE="${ARGOCD_RELEASE:-argocd}"
ARGOCD_CHART_REPO="${ARGOCD_CHART_REPO:-https://argoproj.github.io/argo-helm}"
ARGOCD_CHART_NAME="${ARGOCD_CHART_NAME:-argo-cd}"
ARGOCD_CHART_VERSION="${ARGOCD_CHART_VERSION:-}"     # e.g. "7.7.17"
ARGOCD_TIMEOUT="${ARGOCD_TIMEOUT:-600s}"

# Exposure + TLS (keep ingress even with Istio)
ARGOCD_HOST="${ARGOCD_HOST:-argocd.localhost}"
ARGOCD_INGRESS_CLASS="${ARGOCD_INGRESS_CLASS:-nginx}"
ARGOCD_TLS_SECRET="${ARGOCD_TLS_SECRET:-argocd-tls-secret}"
ARGOCD_ISSUER="${ARGOCD_ISSUER:-selfsigned-ca}"      # cert-manager ClusterIssuer
ARGOCD_CREATE_CERT="${ARGOCD_CREATE_CERT:-true}"

# How long install() will wait for the initial admin secret and show it
ARGOCD_PASSWORD_TIMEOUT_SECS="${ARGOCD_PASSWORD_TIMEOUT_SECS:-120}"

need(){ command -v "$1" >/dev/null 2>&1 || { echo -e "${RED}❌ missing: $1${NC}"; return 1; }; }

_fetch_argocd_password(){
  kubectl -n "${ARGOCD_NS}" get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 --decode || true
}

argocd_install(){
  need helm || return 1
  need kubectl || return 1

  helm repo add argo "${ARGOCD_CHART_REPO}" >/dev/null 2>&1 || true
  helm repo update >/dev/null 2>&1 || true
  kubectl get ns "${ARGOCD_NS}" >/dev/null 2>&1 || kubectl create ns "${ARGOCD_NS}" >/dev/null

  if [[ "${ARGOCD_CREATE_CERT}" == "true" ]]; then
    cat <<EOF | kubectl apply -f - >/dev/null
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: argocd-cert
  namespace: ${ARGOCD_NS}
spec:
  secretName: ${ARGOCD_TLS_SECRET}
  dnsNames:
    - ${ARGOCD_HOST}
  issuerRef:
    name: ${ARGOCD_ISSUER}
    kind: ClusterIssuer
EOF
  fi

  # cm.url removed; keep ingress; add params + cm as requested; set global.domain
  cat <<EOF | helm upgrade --install "${ARGOCD_RELEASE}" argo/"${ARGOCD_CHART_NAME}" \
    --namespace "${ARGOCD_NS}" \
    --create-namespace \
    ${ARGOCD_CHART_VERSION:+--version "${ARGOCD_CHART_VERSION}"} \
    --atomic \
    -f - >/dev/null
global:
  domain: ${ARGOCD_HOST}

configs:
  params:
    server.insecure: "true"
  cm:
    timeout.reconciliation: "30s"

server:
  service:
    type: ClusterIP
  ingress:
    enabled: true
    ingressClassName: ${ARGOCD_INGRESS_CLASS}
    annotations:
      cert-manager.io/cluster-issuer: ${ARGOCD_ISSUER}
    hosts:
      - ${ARGOCD_HOST}
    tls:
      - secretName: ${ARGOCD_TLS_SECRET}
        hosts:
          - ${ARGOCD_HOST}

controller:
  env:
    - name: ARGOCD_SYNC_WAVE_DELAY
      value: "15"
EOF

  kubectl -n "${ARGOCD_NS}" wait --for=condition=Available deploy/${ARGOCD_RELEASE}-server --timeout="${ARGOCD_TIMEOUT}" >/dev/null 2>&1 || true
  kubectl -n "${ARGOCD_NS}" wait --for=condition=Available deploy/${ARGOCD_RELEASE}-repo-server --timeout="${ARGOCD_TIMEOUT}" >/dev/null 2>&1 || true
  kubectl -n "${ARGOCD_NS}" wait --for=condition=Available deploy/${ARGOCD_RELEASE}-application-controller --timeout="${ARGOCD_TIMEOUT}" >/dev/null 2>&1 || true

  echo -e "${GREEN}✅ Argo CD ready at https://${ARGOCD_HOST}${NC}"

  # Show the initial admin password now (keep password command available too)
  end=$((SECONDS + ARGOCD_PASSWORD_TIMEOUT_SECS))
  pw=""
  while [[ $SECONDS -lt $end ]]; do
    pw="$(_fetch_argocd_password)"
    [[ -n "$pw" ]] && break
    sleep 2
  done
  if [[ -n "$pw" ]]; then
    echo -e "${CYAN}🔑 Admin password:${NC} ${pw}"
  else
    echo -e "${YELLOW}⚠️  Admin password not ready yet. Try: $0 password${NC}"
  fi
}

argocd_status(){
  need kubectl || return 1
  kubectl -n "${ARGOCD_NS}" get deploy 2>/dev/null || true
  kubectl -n "${ARGOCD_NS}" get pods -o wide 2>/dev/null || true
  kubectl -n "${ARGOCD_NS}" get svc,ingress 2>/dev/null || true
}

argocd_password(){
  need kubectl || return 1
  pw="$(_fetch_argocd_password)"
  [[ -z "$pw" ]] && { echo -e "${RED}❌ no password yet${NC}"; return 1; }
  echo -e "${GREEN}${pw}${NC}"
}

argocd_uninstall(){
  need helm || return 1
  helm -n "${ARGOCD_NS}" uninstall "${ARGOCD_RELEASE}" >/dev/null 2>&1 || true
  echo -e "${CYAN}namespace kept: ${ARGOCD_NS}${NC}"
}

argocd_help(){
  echo -e "${BOLD}${CYAN}argocd.sh${NC}"
  echo "install | status | password | uninstall | help"
}

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  export -f argocd_install argocd_status argocd_password argocd_uninstall argocd_help
  return 0 2>/dev/null || true
fi

set -euo pipefail
case "${1:-install}" in
  install)    argocd_install ;;
  status)     argocd_status ;;
  password)   argocd_password ;;
  uninstall)  argocd_uninstall ;;
  help|-h|--help) argocd_help ;;
  *) echo -e "${RED}unknown: $1${NC}"; argocd_help; exit 1 ;;
esac
