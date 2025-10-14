#!/usr/bin/env bash

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# ---- Config (override via env) ----
AWX_NS="${AWX_NS:-awx}"
AWX_RELEASE="${AWX_RELEASE:-awx-operator}"
AWX_CHART_REPO="${AWX_CHART_REPO:-https://ansible-community.github.io/awx-operator-helm/}"
AWX_CHART_NAME="${AWX_CHART_NAME:-awx-operator/awx-operator}"
AWX_CHART_VERSION="${AWX_CHART_VERSION:-}"       # e.g. "2.19.0"
AWX_TIMEOUT="${AWX_TIMEOUT:-600s}"

AWX_NAME="${AWX_NAME:-awx-demo}"
AWX_HOST="${AWX_HOST:-awx.localhost}"
AWX_ADMIN_USER="${AWX_ADMIN_USER:-admin}"
AWX_ADMIN_EMAIL="${AWX_ADMIN_EMAIL:-admin@example.com}"
AWX_CREATE_PRELOAD_DATA="${AWX_CREATE_PRELOAD_DATA:-true}"

# Ingress/TLS
AWX_INGRESS_CLASS="${AWX_INGRESS_CLASS:-nginx}"
AWX_TLS_SECRET="${AWX_TLS_SECRET:-awx-tls-secret}"
AWX_ISSUER="${AWX_ISSUER:-selfsigned-ca}"        # ClusterIssuer name that already exists
AWX_CREATE_CERT="${AWX_CREATE_CERT:-true}"       # create cert-manager Certificate for AWX_HOST

need(){ command -v "$1" >/dev/null 2>&1 || { echo -e "${RED}❌ missing: $1${NC}"; return 1; }; }

awx_install(){
  need helm || return 1
  need kubectl || return 1

  echo -e "${YELLOW}📦 Installing/Upgrading AWX Operator in '${AWX_NS}'...${NC}"
  helm repo add awx-operator "${AWX_CHART_REPO}" >/dev/null 2>&1 || true
  helm repo update >/dev/null 2>&1 || true

  kubectl get ns "${AWX_NS}" >/dev/null 2>&1 || kubectl create ns "${AWX_NS}" >/dev/null

  cat <<EOF | helm upgrade --install "${AWX_RELEASE}" "${AWX_CHART_NAME}" \
    --namespace "${AWX_NS}" \
    --create-namespace \
    ${AWX_CHART_VERSION:+--version "${AWX_CHART_VERSION}"} \
    --atomic \
    -f - >/dev/null
# values pass-through if needed
EOF

  echo -e "${BLUE}⏳ Waiting for AWX Operator deployment...${NC}"
  kubectl -n "${AWX_NS}" rollout status deploy/${AWX_RELEASE} --timeout="${AWX_TIMEOUT}" >/dev/null 2>&1 || true

  if [[ "${AWX_CREATE_CERT}" == "true" ]]; then
    echo -e "${YELLOW}🔐 Ensuring TLS Certificate '${AWX_TLS_SECRET}' for ${AWX_HOST}...${NC}"
    cat <<EOF | kubectl apply -f - >/dev/null
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: awx-cert
  namespace: ${AWX_NS}
spec:
  secretName: ${AWX_TLS_SECRET}
  dnsNames:
    - ${AWX_HOST}
  issuerRef:
    name: ${AWX_ISSUER}
    kind: ClusterIssuer
EOF
  fi

  echo -e "${YELLOW}🚀 Applying AWX instance '${AWX_NAME}'...${NC}"
  cat <<EOF | kubectl apply -f - >/dev/null
apiVersion: awx.ansible.com/v1beta1
kind: AWX
metadata:
  name: ${AWX_NAME}
  namespace: ${AWX_NS}
spec:
  service_type: ClusterIP
  admin_user: ${AWX_ADMIN_USER}
  admin_email: ${AWX_ADMIN_EMAIL}
  create_preload_data: ${AWX_CREATE_PRELOAD_DATA}
  ingress_type: ingress
  ingress_class_name: ${AWX_INGRESS_CLASS}
  ingress_tls_secret: ${AWX_TLS_SECRET}
  ingress_hosts:
    - hostname: ${AWX_HOST}
EOF

  echo -e "${BLUE}⏳ Waiting for AWX pods (best-effort)...${NC}"
  kubectl -n "${AWX_NS}" wait --for=condition=Ready pod -l "app.kubernetes.io/managed-by=awx-operator" --timeout="${AWX_TIMEOUT}" >/dev/null 2>&1 || true

  echo -e "${GREEN}✅ AWX install/upgrade complete.${NC}"
  echo -e "${CYAN}🌐 URL:${NC} https://${AWX_HOST}"
}

awx_status(){
  need kubectl || return 1
  if ! kubectl get ns "${AWX_NS}" >/dev/null 2>&1; then
    echo -e "${RED}❌ Namespace '${AWX_NS}' not found.${NC}"
    return 1
  fi

  echo -e "${GREEN}✅ Namespace '${AWX_NS}' present.${NC}"
  echo -e "${BLUE}🔎 Operator Deployment:${NC}"
  kubectl -n "${AWX_NS}" get deploy "${AWX_RELEASE}" 2>/dev/null || true
  echo
  echo -e "${BLUE}📦 AWX CR:${NC}"
  kubectl -n "${AWX_NS}" get awx "${AWX_NAME}" -o wide 2>/dev/null || true
  echo
  echo -e "${BLUE}📦 Pods:${NC}"
  kubectl -n "${AWX_NS}" get pods -o wide 2>/dev/null || true
  echo
  echo -e "${BLUE}🌐 Services & Ingress:${NC}"
  kubectl -n "${AWX_NS}" get svc,ingress 2>/dev/null || true
  echo
  echo -e "${CYAN}🌍 Expected URL:${NC} https://${AWX_HOST}"
}

awx_password(){
  need kubectl || return 1
  local pw
  pw="$(kubectl -n "${AWX_NS}" get secret "${AWX_NAME}-admin-password" -o jsonpath='{.data.password}' 2>/dev/null | base64 --decode || true)"
  if [[ -z "$pw" ]]; then
    echo -e "${RED}❌ Unable to retrieve admin password (secret missing or not ready).${NC}"
    return 1
  fi
  echo -e "${GREEN}AWX Admin Password:${NC} ${pw}"
}

awx_uninstall(){
  need helm || return 1
  need kubectl || return 1

  echo -e "${YELLOW}🧹 Deleting AWX instance '${AWX_NAME}'...${NC}"
  kubectl -n "${AWX_NS}" delete awx "${AWX_NAME}" --ignore-not-found >/dev/null 2>&1 || true

  echo -e "${YELLOW}🧹 Uninstalling AWX Operator release '${AWX_RELEASE}'...${NC}"
  helm -n "${AWX_NS}" uninstall "${AWX_RELEASE}" >/dev/null 2>&1 || true

  # leave namespace for inspection
  echo -e "${CYAN}ℹ️ Namespace '${AWX_NS}' retained. Delete manually if desired: kubectl delete ns ${AWX_NS}${NC}"
  echo -e "${GREEN}✅ Uninstall requested.${NC}"
}

awx_help(){
  echo -e "${BOLD}${CYAN}awx.sh${NC}"
  echo "  install     Install/upgrade AWX Operator and AWX instance"
  echo "  status      Show AWX operator/instance status"
  echo "  password    Print AWX admin password from secret"
  echo "  uninstall   Remove AWX instance and operator (namespace retained)"
  echo "  help        Show this help"
  echo
  echo "Env:"
  echo "  AWX_NS=${AWX_NS}  AWX_RELEASE=${AWX_RELEASE}  AWX_CHART_VERSION=${AWX_CHART_VERSION:-<unset>}  AWX_TIMEOUT=${AWX_TIMEOUT}"
  echo "  AWX_NAME=${AWX_NAME}  AWX_HOST=${AWX_HOST}  AWX_ADMIN_USER=${AWX_ADMIN_USER}  AWX_ADMIN_EMAIL=${AWX_ADMIN_EMAIL}"
  echo "  AWX_INGRESS_CLASS=${AWX_INGRESS_CLASS}  AWX_TLS_SECRET=${AWX_TLS_SECRET}  AWX_ISSUER=${AWX_ISSUER}  AWX_CREATE_CERT=${AWX_CREATE_CERT}"
}

# If sourced, export functions; if executed, run subcommand.
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  export -f awx_install awx_status awx_password awx_uninstall awx_help
  return 0 2>/dev/null || true
fi

set -euo pipefail
case "${1:-install}" in
  install)    awx_install ;;
  status)     awx_status ;;
  password)   awx_password ;;
  uninstall)  awx_uninstall ;;
  help|-h|--help) awx_help ;;
  *) echo -e "${RED}❌ unknown: $1${NC}"; awx_help; exit 1 ;;
esac
