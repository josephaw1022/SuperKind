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
MINIO_HOST_PORT_S3="${MINIO_HOST_PORT_S3:-5100}"        # external port for MinIO S3 API
MINIO_HOST_PORT_CONSOLE="${MINIO_HOST_PORT_CONSOLE:-5101}" # external port for MinIO Console
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

  if docker inspect "${MINIO_NAME}" >/dev/null 2>&1; then
    if [ "$(docker inspect -f '{{.State.Running}}' "${MINIO_NAME}" 2>/dev/null || true)" != "true" ]; then
      docker rm -f "${MINIO_NAME}" >/dev/null 2>&1 || true
    fi
  fi

  if [ "$(docker inspect -f '{{.State.Running}}' "${MINIO_NAME}" 2>/dev/null || true)" != "true" ]; then
    echo -e "${YELLOW}📦 Starting MinIO (S3) on ports ${MINIO_HOST_PORT_S3}/${MINIO_HOST_PORT_CONSOLE}...${NC}"
    docker run -d --restart=unless-stopped \
      --name "${MINIO_NAME}" \
      --network "${KIND_NETWORK}" \
      -v minio-data:/data \
      -p "${MINIO_HOST_PORT_S3}:9000" \
      -p "${MINIO_HOST_PORT_CONSOLE}:9001" \
      -e MINIO_ROOT_USER="${MINIO_ROOT_USER}" \
      -e MINIO_ROOT_PASSWORD="${MINIO_ROOT_PASSWORD}" \
      -e MINIO_ADDRESS=":9000" \
      -e MINIO_CONSOLE_ADDRESS=":9001" \
      quay.io/minio/minio server /data
  else
    echo -e "${CYAN}🗄️  MinIO already running.${NC}"
  fi

  echo -e "${YELLOW}🪣 Ensuring bucket '${VELERO_BUCKET}' exists...${NC}"
  docker run --rm --network "${KIND_NETWORK}" \
    -e MC_HOST_minio="http://${MINIO_ROOT_USER}:${MINIO_ROOT_PASSWORD}@${MINIO_NAME}:9000" \
    quay.io/minio/mc mb -p "minio/${VELERO_BUCKET}"

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

  echo -e "${CYAN}🔑 Creating cloud credentials secret...${NC}"
  kubectl -n "${VELERO_NS}" delete secret cloud-credentials --ignore-not-found >/dev/null 2>&1
  kubectl -n "${VELERO_NS}" create secret generic cloud-credentials \
    --from-literal=cloud="[default]
aws_access_key_id=${MINIO_ROOT_USER}
aws_secret_access_key=${MINIO_ROOT_PASSWORD}" >/dev/null

  local verFlag=()
  [[ -n "$VELERO_CHART_VERSION" ]] && verFlag=(--version "$VELERO_CHART_VERSION")

  echo -e "${YELLOW}📦 Installing Velero Helm chart...${NC}"
  cat <<EOF | helm upgrade --install velero vmware-tanzu/velero \
    --atomic --namespace "${VELERO_NS}" \
    --create-namespace \
    "${verFlag[@]}" \
    -f -
credentials:
  useSecret: true
  existingSecret: cloud-credentials

configuration:
  backupStorageLocation:
    - name: default
      provider: aws
      bucket: ${VELERO_BUCKET}
      accessMode: ReadWrite
      config:
        region: ${VELERO_REGION}
        s3ForcePathStyle: true
        s3Url: http://${MINIO_NAME}:9000
  volumeSnapshotLocation:
    - name: default
      provider: aws
      config:
        region: ${VELERO_REGION}

initContainers:
  - name: velero-plugin-for-aws
    image: ${VELERO_AWS_PLUGIN_IMAGE}
    imagePullPolicy: IfNotPresent
    volumeMounts:
      - name: plugins
        mountPath: /target

kubectl:
  image:
    repository: docker.io/bitnamilegacy/kubectl
    tag: "1.33.4"

EOF



  echo -e "${BLUE}⏳ Waiting for Velero to be Ready...${NC}"
  kubectl -n "${VELERO_NS}" rollout status deploy/velero --timeout="${TIMEOUT}" >/dev/null 2>&1 || true

  kubectl -n velero apply -f - <<'EOF'
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: hourly-all
spec:
  # Every hour at minute 0
  schedule: "0 * * * *"
  template:
    ttl: 168h
    storageLocation: default
EOF


  echo -e "${GREEN}✅ Velero installed successfully.${NC}"
}


_velero_ui_install() {
  need helm || return 1

  echo -e "${YELLOW}🖥️  Installing Velero UI...${NC}"
  helm repo add otwld https://helm.otwld.com/ >/dev/null 2>&1 || true
  helm repo update >/dev/null 2>&1 || true
  kubectl get ns "${VELERO_UI_NS}" >/dev/null 2>&1 || kubectl create ns "${VELERO_UI_NS}" >/dev/null

  cat <<EOF | helm upgrade --install velero-ui otwld/velero-ui \
    --atomic --namespace "${VELERO_UI_NS}" \
    --create-namespace \
    -f - >/dev/null
ingress:
  enabled: true
  className: ${VELERO_UI_INGRESS_CLASS}
  annotations:
    cert-manager.io/cluster-issuer: "${VELERO_UI_ISSUER}"
  hosts:
    - host: ${VELERO_UI_HOST}
      paths:
        - path: /
          pathType: Prefix
  tls:
    - hosts:
        - ${VELERO_UI_HOST}
      secretName: ${VELERO_UI_TLS_SECRET}

rbac:
  create: true
  clusterAdministrator: true
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

  echo -e "${YELLOW}🗑️  Deleting namespaces...${NC}"
  kubectl delete ns "${VELERO_UI_NS}" --ignore-not-found >/dev/null 2>&1 || true
  kubectl delete ns "${VELERO_NS}" --ignore-not-found >/dev/null 2>&1 || true

  echo -e "${YELLOW}🛑 Removing MinIO container and volume...${NC}"
  docker rm -f "${MINIO_NAME}" >/dev/null 2>&1 || true
  docker volume rm -f minio-data >/dev/null 2>&1 || true

  echo -e "${GREEN}✅ Uninstall complete. Everything cleaned up.${NC}"
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
