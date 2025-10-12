#!/usr/bin/env bash
# ~/.kind/plugin/tekton.sh
# Install / Status / Uninstall Tekton via OLM + expose Dashboard with Ingress

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# ---- Config (override with env) ----
TEKTON_NS="${TEKTON_NS:-tekton-pipelines}"
TEKTON_PROFILE="${TEKTON_PROFILE:-all}"
TEKTON_INGRESS_HOST="${TEKTON_INGRESS_HOST:-tekton-dashboard.localhost}"
TEKTON_INGRESS_CLASS="${TEKTON_INGRESS_CLASS:-nginx}"
TEKTON_TLS_SECRET="${TEKTON_TLS_SECRET:-tekton-dashboard-tls}"
TEKTON_ISSUER="${TEKTON_ISSUER:-quick-kind-ca}"           # cert-manager ClusterIssuer
TEKTON_TIMEOUT="${TEKTON_TIMEOUT:-600s}"
OLM_NS="${OLM_NS:-olm}"
OPERATORS_NS="${OPERATORS_NS:-operators}"
TEKTON_OPERATOR_YAML="${TEKTON_OPERATOR_YAML:-https://operatorhub.io/install/tektoncd-operator.yaml}"

need() { command -v "$1" >/dev/null 2>&1 || { echo -e "${RED}❌ missing: $1${NC}"; return 1; }; }

_require_olm_ready() {
  # Basic readiness check for OLM (packageserver CSV Succeeded)
  if ! kubectl get ns "${OLM_NS}" >/dev/null 2>&1; then
    echo -e "${RED}❌ OLM namespace '${OLM_NS}' not found. Install OLM first (e.g., 'kind-plugin olm install').${NC}"
    return 1
  fi
  local phase
  phase="$(kubectl -n "${OLM_NS}" get csv -o jsonpath='{range .items[?(@.metadata.name=="packageserver")]}{.status.phase}{end}' 2>/dev/null || true)"
  if [[ "$phase" != "Succeeded" ]]; then
    echo -e "${YELLOW}⏳ OLM PackageServer CSV phase is '${phase:-<unknown>}' — Tekton operator install may fail until OLM is ready.${NC}"
  fi
  return 0
}

_wait_csv_succeeded() {
  # $1: namespace, $2: regex for CSV name
  local ns="$1" regex="$2"
  local end=$((SECONDS+600))
  while (( SECONDS < end )); do
    # find matching CSV name(s), then check any with Succeeded
    local line
    line="$(kubectl -n "$ns" get csv --no-headers 2>/dev/null | grep -E "$regex" || true)"
    if [[ -n "$line" ]] && echo "$line" | awk '{print $NF}' | grep -q "^Succeeded$"; then
      return 0
    fi
    sleep 3
  done
  return 1
}

tekton_install() {
  need kubectl || return 1

  _require_olm_ready || return 1

  echo -e "${YELLOW}📦 Installing Tekton Operator via OLM subscription (OperatorHub manifest)...${NC}"
  kubectl get ns "${OPERATORS_NS}" >/dev/null 2>&1 || kubectl create ns "${OPERATORS_NS}" >/dev/null
  kubectl create -f "${TEKTON_OPERATOR_YAML}" >/dev/null 2>&1 || true

  echo -e "${BLUE}⏳ Waiting for Tekton Operator CSV to be Succeeded in '${OPERATORS_NS}'...${NC}"
  if _wait_csv_succeeded "${OPERATORS_NS}" "tektoncd-operator"; then
    echo -e "${GREEN}✅ Tekton Operator CSV is Succeeded.${NC}"
  else
    echo -e "${YELLOW}⚠️ Timed out waiting for Tekton Operator CSV; continuing. Check 'kubectl get csv -n ${OPERATORS_NS}'.${NC}"
  fi

  echo -e "${YELLOW}🧭 Ensuring target namespace '${TEKTON_NS}' exists...${NC}"
  kubectl get ns "${TEKTON_NS}" >/dev/null 2>&1 || kubectl create ns "${TEKTON_NS}" >/dev/null

  echo -e "${YELLOW}📝 Applying TektonConfig (profile=${TEKTON_PROFILE}, targetNamespace=${TEKTON_NS})...${NC}"
  cat <<EOF | kubectl apply -f - >/dev/null
apiVersion: operator.tekton.dev/v1alpha1
kind: TektonConfig
metadata:
  name: config
  namespace: ${TEKTON_NS}
spec:
  profile: ${TEKTON_PROFILE}
  targetNamespace: ${TEKTON_NS}
  pruner:
    resources:
      - pipelinerun
      - taskrun
    keep: 100
    schedule: "0 8 * * *"
  pipeline:
    enable-tekton-oci-bundles: true
  dashboard:
    readonly: false
EOF

  echo -e "${BLUE}⏳ Waiting for Tekton components to be Ready (${TEKTON_TIMEOUT})...${NC}"
  # Best-effort waits (some names may vary by operator version)
  for deploy in tekton-operator tekton-pipelines-controller tekton-dashboard; do
    kubectl -n "${TEKTON_NS}" rollout status deploy/"$deploy" --timeout="${TEKTON_TIMEOUT}" >/dev/null 2>&1 || true
  done

  echo -e "${YELLOW}🌐 Creating Ingress for Tekton Dashboard at https://${TEKTON_INGRESS_HOST} ...${NC}"
  # Dashboard service commonly: tekton-dashboard, port 9097
  cat <<EOF | kubectl apply -f - >/dev/null
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tekton-dashboard
  namespace: ${TEKTON_NS}
  annotations:
    cert-manager.io/cluster-issuer: "${TEKTON_ISSUER}"
spec:
  ingressClassName: ${TEKTON_INGRESS_CLASS}
  tls:
    - hosts:
        - ${TEKTON_INGRESS_HOST}
      secretName: ${TEKTON_TLS_SECRET}
  rules:
    - host: ${TEKTON_INGRESS_HOST}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: tekton-dashboard
                port:
                  number: 9097
EOF

  echo -e "${GREEN}✅ Tekton installed (Operator + TektonConfig).${NC}"
  echo -e "${CYAN}📍 Dashboard:${NC} https://${TEKTON_INGRESS_HOST}"
  echo -e "${CYAN}🔎 CSVs:${NC} kubectl get csv -n ${OPERATORS_NS}"
}

tekton_status() {
  need kubectl || return 1

  echo -e "${BLUE}🔎 Tekton Operator CSVs in '${OPERATORS_NS}':${NC}"
  kubectl -n "${OPERATORS_NS}" get csv 2>/dev/null || echo "  (none)"

  echo -e "\n${BLUE}📦 Tekton resources in '${TEKTON_NS}':${NC}"
  if kubectl get ns "${TEKTON_NS}" >/dev/null 2>&1; then
    kubectl -n "${TEKTON_NS}" get deploy,svc,ingress 2>/dev/null || true
  else
    echo "  (namespace '${TEKTON_NS}' not found)"
  fi

  echo -e "\n${CYAN}🌍 Dashboard URL:${NC} https://${TEKTON_INGRESS_HOST}"
}

tekton_uninstall() {
  need kubectl || return 1

  echo -e "${YELLOW}🧹 Removing TektonConfig and Dashboard Ingress from '${TEKTON_NS}'...${NC}"
  kubectl -n "${TEKTON_NS}" delete ingress tekton-dashboard --ignore-not-found >/dev/null 2>&1 || true
  kubectl -n "${TEKTON_NS}" delete tektonconfig config --ignore-not-found >/dev/null 2>&1 || true

  echo -e "${YELLOW}🧹 Uninstalling Tekton Operator subscription (cluster-wide) from '${OPERATORS_NS}'...${NC}"
  kubectl delete -f "${TEKTON_OPERATOR_YAML}" --ignore-not-found >/dev/null 2>&1 || true

  echo -e "${CYAN}ℹ️ Namespaces '${TEKTON_NS}' and '${OPERATORS_NS}' are retained. Remove them manually if desired.${NC}"
  echo -e "${GREEN}✅ Uninstall requested.${NC}"
}

tekton_help() {
  echo -e "${BOLD}${CYAN}tekton.sh${NC} (via OLM)"
  echo "  install     Install Tekton Operator (OLM) + TektonConfig + Dashboard Ingress"
  echo "  status      Show Operator CSVs and Tekton workloads"
  echo "  uninstall   Remove TektonConfig/Ingress and Operator subscription"
  echo "  help        Show this help"
  echo
  echo "Env:"
  echo "  TEKTON_NS=${TEKTON_NS}"
  echo "  TEKTON_PROFILE=${TEKTON_PROFILE}"
  echo "  TEKTON_INGRESS_HOST=${TEKTON_INGRESS_HOST}"
  echo "  TEKTON_INGRESS_CLASS=${TEKTON_INGRESS_CLASS}"
  echo "  TEKTON_TLS_SECRET=${TEKTON_TLS_SECRET}"
  echo "  TEKTON_ISSUER=${TEKTON_ISSUER}"
  echo "  TEKTON_TIMEOUT=${TEKTON_TIMEOUT}"
  echo "  OPERATORS_NS=${OPERATORS_NS}"
  echo "  OLM_NS=${OLM_NS}"
  echo "  TEKTON_OPERATOR_YAML=${TEKTON_OPERATOR_YAML}"
}

# If sourced, export functions
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  export -f tekton_install tekton_status tekton_uninstall tekton_help
  return 0 2>/dev/null || true
fi

# Executed directly
set -euo pipefail
case "${1:-install}" in
  install)    tekton_install ;;
  status)     tekton_status ;;
  uninstall)  tekton_uninstall ;;
  help|-h|--help) tekton_help ;;
  *) echo -e "${RED}❌ unknown: $1${NC}"; tekton_help; exit 1 ;;
esac
