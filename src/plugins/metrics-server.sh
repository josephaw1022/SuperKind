#!/usr/bin/env bash
# ~/.kind/plugin/metrics-server.sh
# Install / Status / Uninstall metrics-server (for HPA support)

set -euo pipefail
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

MS_NAMESPACE="${MS_NAMESPACE:-kube-system}"     # install into kube-system
MS_RELEASE="${MS_RELEASE:-metrics-server}"
MS_CHART_REPO="${MS_CHART_REPO:-https://kubernetes-sigs.github.io/metrics-server/}"
MS_CHART_NAME="${MS_CHART_NAME:-metrics-server/metrics-server}"
MS_CHART_VERSION="${MS_CHART_VERSION:-}"        # e.g. "3.12.1" (optional pin)
MS_RESOLUTION="${MS_RESOLUTION:-15s}"           # scrape resolution

need() { command -v "$1" >/dev/null 2>&1 || { echo -e "${RED}❌ missing: $1${NC}"; return 1; }; }

metrics_install() {
  need helm || return 1
  need kubectl || return 1

  echo -e "${YELLOW}📈 Installing metrics-server (for HPA)…${NC}"
  helm repo add metrics-server "${MS_CHART_REPO}" >/dev/null 2>&1 || true
  helm repo update >/dev/null 2>&1 || true

  # Values tuned for Kind: accept self-signed kubelet certs and use InternalIP
  cat <<EOF | helm upgrade --install "${MS_RELEASE}" "${MS_CHART_NAME}" \
    --namespace "${MS_NAMESPACE}" \
    --create-namespace \
    ${MS_CHART_VERSION:+--version "${MS_CHART_VERSION}"} \
    --atomic \
    -f - >/dev/null
args:
  - --kubelet-preferred-address-types=InternalIP,Hostname,ExternalIP
  - --kubelet-insecure-tls
  - --metric-resolution=${MS_RESOLUTION}
# Increase request/limits a touch for noisy clusters (optional)
resources:
  requests:
    cpu: 50m
    memory: 64Mi
  limits:
    cpu: 200m
    memory: 256Mi
EOF

  echo -e "${BLUE}⏳ Waiting for metrics-server APIService to be Ready…${NC}"
  # Wait for Deployment and APIService readiness
  kubectl -n "${MS_NAMESPACE}" rollout status deploy/${MS_RELEASE} --timeout=120s >/dev/null 2>&1 || true
  kubectl wait --for=condition=Available apiservice v1beta1.metrics.k8s.io --timeout=120s >/dev/null 2>&1 || true

  echo -e "${GREEN}✅ metrics-server installed.${NC}"
  echo -e "${CYAN}Try: kubectl top nodes && kubectl top pods -A${NC}"
}

metrics_status() {
  echo -e "${BLUE}🔎 metrics-server status:${NC}"
  kubectl -n "${MS_NAMESPACE}" get deploy,po -l "app.kubernetes.io/name=metrics-server" 2>/dev/null || true
  echo
  kubectl get apiservice v1beta1.metrics.k8s.io -o wide 2>/dev/null || true
  echo
  echo -e "${CYAN}Smoke test:${NC} kubectl top nodes || true"
}

metrics_uninstall() {
  echo -e "${YELLOW}🧹 Uninstalling metrics-server…${NC}"
  helm -n "${MS_NAMESPACE}" uninstall "${MS_RELEASE}" >/dev/null 2>&1 || true
  # Keep namespace kube-system intact; no deletion here.
  echo -e "${GREEN}✅ Uninstalled.${NC}"
}

metrics_help() {
  echo -e "${BOLD}${CYAN}metrics-server plugin${NC}"
  echo "  install     Install metrics-server (Kind-safe args)"
  echo "  status      Show status & APIService availability"
  echo "  uninstall   Remove the Helm release"
  echo "  help        Show this help"
  echo
  echo "  Env overrides:"
  echo "    MS_NAMESPACE (default: kube-system)"
  echo "    MS_CHART_VERSION (e.g. 3.12.1)"
  echo "    MS_RESOLUTION (default: 15s)"
}

# export funcs if sourced by a dispatcher
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  export -f metrics_install metrics_status metrics_uninstall metrics_help
  return 0 2>/dev/null || true
fi

case "${1:-install}" in
  install)    metrics_install ;;
  status)     metrics_status ;;
  uninstall)  metrics_uninstall ;;
  help|-h|--help) metrics_help ;;
  *) echo -e "${RED}❌ unknown: $1${NC}"; metrics_help; exit 1 ;;
esac
