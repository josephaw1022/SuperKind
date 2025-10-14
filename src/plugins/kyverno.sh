#!/usr/bin/env bash

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# ---- Config (override via env) ----
KYVERNO_NS="${KYVERNO_NS:-kyverno}"
KYVERNO_RELEASE="${KYVERNO_RELEASE:-kyverno}"
KYVERNO_POLICIES_RELEASE="${KYVERNO_POLICIES_RELEASE:-kyverno-policies}"
KYVERNO_CHART_REPO="${KYVERNO_CHART_REPO:-https://kyverno.github.io/kyverno}"
KYVERNO_CHART_NAME="${KYVERNO_CHART_NAME:-kyverno/kyverno}"
KYVERNO_POLICIES_CHART_NAME="${KYVERNO_POLICIES_CHART_NAME:-kyverno/kyverno-policies}"
KYVERNO_TIMEOUT="${KYVERNO_TIMEOUT:-600s}"
KYVERNO_CHART_VERSION="${KYVERNO_CHART_VERSION:-}"            # e.g. "3.2.5"
KYVERNO_POLICIES_CHART_VERSION="${KYVERNO_POLICIES_CHART_VERSION:-}"

PR_NS="${PR_NS:-policy-reporter}"
PR_RELEASE="${PR_RELEASE:-policy-reporter}"
PR_HOST="${PR_HOST:-policy-reporter.localhost}"
PR_CHART_REPO="${PR_CHART_REPO:-https://kyverno.github.io/policy-reporter}"
PR_CHART_NAME="${PR_CHART_NAME:-policy-reporter/policy-reporter}"
PR_CHART_VERSION="${PR_CHART_VERSION:-}"
PR_INGRESS_CLASS="${PR_INGRESS_CLASS:-nginx}"
PR_TLS_SECRET="${PR_TLS_SECRET:-policy-reporter-tls}"
PR_ISSUER="${PR_ISSUER:-selfsigned-ca}"         # cert-manager ClusterIssuer name
PR_CREATE_CERT="${PR_CREATE_CERT:-true}"
PR_TIMEOUT="${PR_TIMEOUT:-600s}"

need(){ command -v "$1" >/dev/null 2>&1 || { echo -e "${RED}❌ missing: $1${NC}"; return 1; }; }

kyverno_install(){
    need helm || return 1
    need kubectl || return 1
    
    echo -e "${YELLOW}📦 Adding Helm repos...${NC}"
    helm repo add kyverno "${KYVERNO_CHART_REPO}" >/dev/null 2>&1 || true
    helm repo add policy-reporter "${PR_CHART_REPO}" >/dev/null 2>&1 || true
    helm repo update >/dev/null 2>&1 || true
    
    echo -e "${YELLOW}🚀 Installing/Upgrading Kyverno...${NC}"
    kubectl get ns "${KYVERNO_NS}" >/dev/null 2>&1 || kubectl create ns "${KYVERNO_NS}" >/dev/null
  cat <<EOF | helm upgrade --install "${KYVERNO_RELEASE}" "${KYVERNO_CHART_NAME}" \
    --namespace "${KYVERNO_NS}" \
    --create-namespace \
    ${KYVERNO_CHART_VERSION:+--version "${KYVERNO_CHART_VERSION}"} \
    --atomic \
    -f - >/dev/null
# values pass-through if needed
EOF
    
    echo -e "${BLUE}⏳ Waiting for Kyverno controller to be Available...${NC}"
    kubectl -n "${KYVERNO_NS}" rollout status deploy/kyverno --timeout="${KYVERNO_TIMEOUT}" >/dev/null 2>&1 || true
    
    echo -e "${YELLOW}🛡  Installing Kyverno Pod Security Policies...${NC}"
  cat <<EOF | helm upgrade --install "${KYVERNO_POLICIES_RELEASE}" "${KYVERNO_POLICIES_CHART_NAME}" \
    --namespace "${KYVERNO_NS}" \
    ${KYVERNO_POLICIES_CHART_VERSION:+--version "${KYVERNO_POLICIES_CHART_VERSION}"} \
    --atomic \
    -f - >/dev/null
# default policy set
EOF
    
    kubectl get ns "${PR_NS}" >/dev/null 2>&1 || kubectl create ns "${PR_NS}" >/dev/null
    
    
    # Optional TLS cert for Policy Reporter
    if [[ "${PR_CREATE_CERT}" == "true" ]]; then
        echo -e "${YELLOW}🔐 Ensuring TLS Certificate for ${PR_HOST}...${NC}"
    cat <<EOF | kubectl apply -f - >/dev/null
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ${PR_RELEASE}-cert
  namespace: ${PR_NS}
spec:
  secretName: ${PR_TLS_SECRET}
  dnsNames:
    - ${PR_HOST}
  issuerRef:
    name: ${PR_ISSUER}
    kind: ClusterIssuer
EOF
    fi
    
    echo -e "${YELLOW}📊 Installing/Upgrading Policy Reporter (UI + Ingress)...${NC}"
    kubectl get ns "${PR_NS}" >/dev/null 2>&1 || kubectl create ns "${PR_NS}" >/dev/null
  cat <<EOF | helm upgrade --install "${PR_RELEASE}" "${PR_CHART_NAME}" \
    --namespace "${PR_NS}" \
    --create-namespace \
    ${PR_CHART_VERSION:+--version "${PR_CHART_VERSION}"} \
    --atomic \
    -f - >/dev/null
ui:
  enabled: true
  ingress:
    enabled: true
    className: ${PR_INGRESS_CLASS}
    hosts:
      - host: ${PR_HOST}
        paths:
          - path: /
            pathType: Prefix
    tls:
      - secretName: ${PR_TLS_SECRET}
        hosts:
          - ${PR_HOST}
EOF
    
    echo -e "${BLUE}⏳ Waiting for Policy Reporter UI...${NC}"
    kubectl -n "${PR_NS}" rollout status deploy/${PR_RELEASE}-ui --timeout="${PR_TIMEOUT}" >/dev/null 2>&1 || true
    
    echo -e "${GREEN}✅ Kyverno + Policies + Policy Reporter installed.${NC}"
    echo -e "${CYAN}🌐 Policy Reporter UI:${NC} https://${PR_HOST}"
}

kyverno_status(){
    need kubectl || return 1
    echo -e "${BLUE}🔎 Kyverno (${KYVERNO_NS}) deployments/pods:${NC}"
    kubectl -n "${KYVERNO_NS}" get deploy,po 2>/dev/null || true
    echo
    echo -e "${BLUE}📦 Kyverno CRDs (snippet):${NC}"
    kubectl get crd | grep -E '^clusterpolicies\.kyverno\.io|^policies\.kyverno\.io' || true
    echo
    echo -e "${BLUE}📊 Policy Reporter (${PR_NS}) resources:${NC}"
    kubectl -n "${PR_NS}" get deploy,po,svc,ingress 2>/dev/null || true
    echo
    echo -e "${CYAN}🌍 Policy Reporter URL:${NC} https://${PR_HOST}"
}

kyverno_uninstall(){
    need helm || return 1
    need kubectl || return 1
    echo -e "${YELLOW}🧹 Uninstalling Policy Reporter...${NC}"
    helm -n "${PR_NS}" uninstall "${PR_RELEASE}" >/dev/null 2>&1 || true
    echo -e "${YELLOW}🧹 Uninstalling Kyverno Policies...${NC}"
    helm -n "${KYVERNO_NS}" uninstall "${KYVERNO_POLICIES_RELEASE}" >/dev/null 2>&1 || true
    echo -e "${YELLOW}🧹 Uninstalling Kyverno...${NC}"
    helm -n "${KYVERNO_NS}" uninstall "${KYVERNO_RELEASE}" >/dev/null 2>&1 || true
    echo -e "${CYAN}ℹ️ Namespaces retained: ${KYVERNO_NS}, ${PR_NS}${NC}"
    echo -e "${GREEN}✅ Uninstall requested.${NC}"
}

kyverno_help(){
    echo -e "${BOLD}${CYAN}kyverno.sh${NC}"
    echo "  install     Install/upgrade Kyverno, Kyverno policies, and Policy Reporter (with Ingress)"
    echo "  status      Show status for Kyverno and Policy Reporter"
    echo "  uninstall   Remove Kyverno, policies, and Policy Reporter (namespaces retained)"
    echo "  help        Show this help"
    echo
    echo "Env (common):"
    echo "  KYVERNO_NS=${KYVERNO_NS}  KYVERNO_RELEASE=${KYVERNO_RELEASE}  KYVERNO_TIMEOUT=${KYVERNO_TIMEOUT}"
    echo "  KYVERNO_CHART_VERSION=${KYVERNO_CHART_VERSION:-<unset>}  KYVERNO_POLICIES_CHART_VERSION=${KYVERNO_POLICIES_CHART_VERSION:-<unset>}"
    echo
    echo "Policy Reporter:"
    echo "  PR_NS=${PR_NS}  PR_RELEASE=${PR_RELEASE}  PR_HOST=${PR_HOST}"
    echo "  PR_INGRESS_CLASS=${PR_INGRESS_CLASS}  PR_TLS_SECRET=${PR_TLS_SECRET}  PR_ISSUER=${PR_ISSUER}  PR_CREATE_CERT=${PR_CREATE_CERT}"
}

# If sourced, export functions; if executed, run subcommand.
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    export -f kyverno_install kyverno_status kyverno_uninstall kyverno_help
    return 0 2>/dev/null || true
fi

set -euo pipefail
case "${1:-install}" in
    install)    kyverno_install ;;
    status)     kyverno_status ;;
    uninstall)  kyverno_uninstall ;;
    help|-h|--help) kyverno_help ;;
    *) echo -e "${RED}❌ unknown: $1${NC}"; kyverno_help; exit 1 ;;
esac
