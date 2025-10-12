#!/usr/bin/env bash
# ~/.kind/plugin/velero.sh
# Install / Status / Uninstall:
# - MinIO (S3) container in Kind network (ports 5000/5001)
# - Velero with MinIO as S3 backend
# - Velero UI + Ingress for dashboard

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# ---- Config (override via env) ----
# MinIO
MINIO_NAME="${MINIO_NAME:-minio}"
MINIO_HOST_PORT_S3="${MINIO_HOST_PORT_S3:-5000}"        # external port for MinIO S3 API
MINIO_HOST_PORT_CONSOLE="${MINIO_HOST_PORT_CONSOLE:-5001}" # external port for MinIO Console
MINIO_ROOT_USER="${MINIO_ROOT_USER:-velero}"
MINIO_ROOT_PASSWORD="${MINIO_ROOT_PASSWORD:-veleropass123}"
VELERO_BUCKET="${VELERO_BUCKET:-velero}"

# Velero
VELERO_NS="${VELERO_NS:-velero}"
VELERO_REGION="${VELERO_REGION:-us-east-1}"
VELERO_CHART_VERSION="${VELERO_CHART_VERSION:-}"         # e.g. "11.0.0"
VELERO_AWS_PLUGIN_IMAGE="${VELERO_AWS_PLUGIN_IMAGE:-velero/velero-plugin-for-aws:v1.9.0}"

# Velero UI
VELERO_UI_NS="${VELERO_UI_NS:-velero-ui}"
VELERO_UI_HOST="${VELERO_UI_HOST:-velero-ui.localhost}"
VELERO_UI_TLS_SECRET="${VELERO_UI_TLS_SECRET:-velero-ui-tls}"
VELERO_UI_ISSUER="${VELERO_UI_ISSUER:-quick-kind-ca}"    # cert-manager ClusterIssuer
VELERO_UI_INGRESS_CLASS="${VELERO_UI_INGRESS_CLASS:-nginx}"

# Misc
KIND_NETWORK="${KIND_NETWORK:-kind}"
TIMEOUT="${TIMEOUT:-600s}"

need() { command -v "$1" >/dev/null 2>&1 || { echo -e "${RED}❌ missing: $1${NC}"; return 1; }; }

_minio_up() {
  need docker || return 1

  if [ "$(docker inspect -f '{{.State.Running}}' "${MINIO_NAME}" 2>/dev/null || true)" != "true" ]; then
    echo -e "${YELLOW}📦 Starting MinIO (S3) on localhost:${MINIO_HOST_PORT_S3} / ${MINIO_HOST_PORT_CONSOLE} ...${NC}"
    docker run -d --restart=always \
      --name "${MINIO_NAME}" \
      --network "${KIND_NETWORK}" \
      -p "127.0.0.1:${MINIO_HOST_PORT_S3}:9000" \
      -p "127.0.0.1:${MINIO_HOST_PORT_CONSOLE}:9001" \
      -e MINIO_ROOT_USER="${MINIO_ROOT_USER}" \
      -e MINIO_ROOT_PASSWORD="${MINIO_ROOT_PASSWORD}" \
      quay.io/minio/minio server /data --console-address ":9001" >/dev/null
  else
    echo -e "${CYAN}🗄️  MinIO already running.${NC}"
  fi

  docker network connect "${KIND_NETWORK}" "${MINIO_NAME}" >/dev/null 2>&1 || true

  echo -e "${YELLOW}🪣 Ensuring bucket '${VELERO_BUCKET}' exists...${NC}"
  docker run --rm --network "${KIND_NETWORK}" \
    -e MC_HOST_minio="http://${MINIO_ROOT_USER}:${MINIO_ROOT_PASSWORD}@${MINIO_NAME}:9000" \
    minio/mc mb -p "minio/${VELERO_BUCKET}" >/dev/null 2>&1 || true

  echo -e "${GREEN}✅ MinIO ready.${NC}"
  echo -e "${CYAN}🌍 Console: http://localhost:${MINIO_HOST_PORT_CONSOLE}${NC}"
  echo -e "${CYAN}📦 S3 API:  http://localhost:${MINIO_HOST_PORT_S3}${NC}"
}

_velero_install() {
  need kubectl || return 1
  need helm || return 1

  echo -e "${YELLOW}📦 Installing Velero (with MinIO S3 backend)...${NC}"
  helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts >/dev/null 2>&1 || true
  helm repo update >/dev/null 2>&1 || true
  kubectl get ns "${VELERO_NS}" >/dev/null 2>&1 || kubectl create ns "${VELERO_NS}" >/dev/null

  local aws_creds="[default]
aws_access_key_id=${MINIO_ROOT_USER}
aws_secret_access_key=${MINIO_ROOT_PASSWORD}
"
  kubectl -n "${VELERO_NS}" create secret generic cloud-credentials \
    --from-literal=cloud="${aws_creds}" \
    --dry-run=client -o yaml | kubectl apply -f - >/dev/null

  local verFlag=()
  [[ -n "$VELERO_CHART_VERSION" ]] && verFlag=(--version "$VELERO_CHART_VERSION")

  helm upgrade --install velero vmware-tanzu/velero \
    --namespace "${VELERO_NS}" \
    "${verFlag[@]}" \
    --set configuration.provider=aws \
    --set credentials.existingSecret=cloud-credentials \
    --set configuration.backupStorageLocation.name=default \
    --set configuration.backupStorageLocation.bucket="${VELERO_BUCKET}" \
    --set configuration.backupStorageLocation.config.region="${VELERO_REGION}" \
    --set configuration.backupStorageLocation.config.s3ForcePathStyle=true \
    --set configuration.backupStorageLocation.config.s3Url="http://${MINIO_NAME}:9000" \
    --set configuration.volumeSnapshotLocation.name=default \
    --set configuration.volumeSnapshotLocation.config.region="${VELERO_REGION}" \
    --set "initContainers[0].name=velero-plugin-for-aws" \
    --set "initContainers[0].image=${VELERO_AWS_PLUGIN_IMAGE}" \
    --set "initContainers[0].volumeMounts[0].mountPath=/target" \
    --set "initContainers[0].volumeMounts[0].name=plugins" >/dev/null

  echo -e "${BLUE}⏳ Waiting for Velero to be Ready...${NC}"
  kubectl -n "${VELERO_NS}" rollout status deploy/velero --timeout="${TIMEOUT}" >/dev/null 2>&1 || true
  echo -e "${GREEN}✅ Velero installed successfully.${NC}"
}

_velero_ui_install() {
  need helm || return 1
  echo -e "${YELLOW}🖥️  Installing Velero UI...${NC}"
  helm repo add otwld https://helm.otwld.com/ >/dev/null 2>&1 || true
  helm repo update >/dev/null 2>&1 || true
  kubectl get ns "${VELERO_UI_NS}" >/dev/null 2>&1 || kubectl create ns "${VELERO_UI_NS}" >/dev/null

  helm upgrade --install velero-ui otwld/velero-ui \
    --namespace "${VELERO_UI_NS}" >/dev/null

  echo -e "${YELLOW}🌐 Creating Ingress for Velero UI (https://${VELERO_UI_HOST})...${NC}"
  cat <<EOF | kubectl apply -f - >/dev/null
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: velero-ui
  namespace: ${VELERO_UI_NS}
  annotations:
    cert-manager.io/cluster-issuer: "${VELERO_UI_ISSUER}"
spec:
  ingressClassName: ${VELERO_UI_INGRESS_CLASS}
  tls:
    - hosts:
        - ${VELERO_UI_HOST}
      secretName: ${VELERO_UI_TLS_SECRET}
  rules:
    - host: ${VELERO_UI_HOST}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: velero-ui
                port:
                  number: 80
EOF

  echo -e "${GREEN}✅ Velero UI installed.${NC}"
  echo -e "${CYAN}🔑 Default creds: admin / admin${NC}"
  echo -e "${CYAN}📍 URL: https://${VELERO_UI_HOST}${NC}"
}

velero_install() {
  _minio_up
  _velero_install
  _velero_ui_install
}

velero_status() {
  echo -e "${BLUE}🔎 MinIO:${NC}"
  docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "^${MINIO_NAME}\b" || echo "  (not running)"

  echo -e "\n${BLUE}🔎 Velero:${NC}"
  kubectl -n "${VELERO_NS}" get deploy,svc,po 2>/dev/null || echo "  (missing namespace)"

  echo -e "\n${BLUE}🔎 Velero UI:${NC}"
  kubectl -n "${VELERO_UI_NS}" get deploy,svc,ingress 2>/dev/null || echo "  (missing namespace)"

  echo -e "\n${CYAN}🌍 Dashboard:${NC} https://${VELERO_UI_HOST}"
  echo -e "${CYAN}🗄️  MinIO Console:${NC} http://localhost:${MINIO_HOST_PORT_CONSOLE}"
}

velero_uninstall() {
  echo -e "${YELLOW}🧹 Removing Velero UI and Velero...${NC}"
  helm -n "${VELERO_UI_NS}" uninstall velero-ui >/dev/null 2>&1 || true
  kubectl -n "${VELERO_UI_NS}" delete ingress velero-ui --ignore-not-found >/dev/null 2>&1 || true
  helm -n "${VELERO_NS}" uninstall velero >/dev/null 2>&1 || true
  kubectl -n "${VELERO_NS}" delete secret cloud-credentials --ignore-not-found >/dev/null 2>&1 || true

  echo -e "${CYAN}ℹ️ MinIO container left running for reuse.${NC}"
  echo -e "${GREEN}✅ Uninstall complete.${NC}"
}

velero_help() {
  echo -e "${BOLD}${CYAN}velero.sh${NC}"
  echo "  install     Start MinIO (ports 5000/5001), install Velero + UI + Ingress"
  echo "  status      Show current Velero and MinIO status"
  echo "  uninstall   Remove Helm releases (keeps MinIO)"
  echo "  help        Show this help"
}

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  export -f velero_install velero_status velero_uninstall velero_help
  return 0 2>/dev/null || true
fi

set -euo pipefail
case "${1:-install}" in
  install)    velero_install ;;
  status)     velero_status ;;
  uninstall)  velero_uninstall ;;
  help|-h|--help) velero_help ;;
  *) echo -e "${RED}❌ unknown: $1${NC}"; velero_help; exit 1 ;;
esac
