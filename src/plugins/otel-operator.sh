#!/usr/bin/env bash

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

OTEL_NS="${OTEL_NS:-opentelemetry-operator-system}"
OTEL_RELEASE="${OTEL_RELEASE:-opentelemetry-operator}"
OTEL_CHART_REPO="${OTEL_CHART_REPO:-https://open-telemetry.github.io/opentelemetry-helm-charts}"
OTEL_CHART_NAME="${OTEL_CHART_NAME:-open-telemetry/opentelemetry-operator}"
OTEL_CHART_VERSION="${OTEL_CHART_VERSION:-}"
OTEL_TIMEOUT="${OTEL_TIMEOUT:-600s}"

CA_SECRET_NAME="${CA_SECRET_NAME:-quick-kind-ca}"
CA_ISSUER_NAME="${CA_ISSUER_NAME:-quick-kind-ca}"

OTEL_COLLECTOR_IMAGE_REPO="${OTEL_COLLECTOR_IMAGE_REPO:-otel/opentelemetry-collector-k8s}"
OTEL_ADMISSION_CERTMANAGER_ENABLED="${OTEL_ADMISSION_CERTMANAGER_ENABLED:-true}"
OTEL_ADMISSION_AUTOCERT_ENABLED="${OTEL_ADMISSION_AUTOCERT_ENABLED:-true}"

OTEL_SIMPLEST_NS="${OTEL_SIMPLEST_NS:-observability}"
ASPIRE_DASHBOARD_IMAGE="${ASPIRE_DASHBOARD_IMAGE:-mcr.microsoft.com/dotnet/aspire-dashboard:latest}"
ASPIRE_DASHBOARD_PORT="${ASPIRE_DASHBOARD_PORT:-18888}"
ASPIRE_INGRESS_CLASS="${ASPIRE_INGRESS_CLASS:-nginx}"
ASPIRE_TLS_SECRET="${ASPIRE_TLS_SECRET:-aspire-dashboard-tls}"
ASPIRE_INGRESS_HOST="${ASPIRE_INGRESS_HOST:-aspire-dashboard.localhost}"

need(){
    command -v "$1" >/dev/null 2>&1 || { echo -e "${RED}❌ missing: $1${NC}"; return 1; }
}

otel_install(){
    need helm || return 1
    need kubectl || return 1
    
    echo -e "${YELLOW}📦 Adding Helm repo...${NC}"
    helm repo add open-telemetry "${OTEL_CHART_REPO}" >/dev/null 2>&1 || true
    helm repo update >/dev/null 2>&1 || true
    
    echo -e "${YELLOW}🚀 Installing/Upgrading OpenTelemetry Operator (Quick Kind CA)...${NC}"
    kubectl get ns "${OTEL_NS}" >/dev/null 2>&1 || kubectl create ns "${OTEL_NS}" >/dev/null
    
  cat <<EOF | helm upgrade --install "${OTEL_RELEASE}" "${OTEL_CHART_NAME}" \
    --namespace "${OTEL_NS}" \
    --create-namespace \
    ${OTEL_CHART_VERSION:+--version "${OTEL_CHART_VERSION}"} \
    --atomic \
    -f - >/dev/null
manager:
  collectorImage:
    repository: ${OTEL_COLLECTOR_IMAGE_REPO}
admissionWebhooks:
  certManager:
    enabled: ${OTEL_ADMISSION_CERTMANAGER_ENABLED}
    issuerRef:
      name: ${CA_ISSUER_NAME}
      kind: ClusterIssuer
  autoGenerateCert:
    enabled: ${OTEL_ADMISSION_AUTOCERT_ENABLED}
EOF
    
    echo -e "${BLUE}⏳ Waiting for operator deployment to be Available...${NC}"
    kubectl -n "${OTEL_NS}" rollout status deploy -l app.kubernetes.io/name=opentelemetry-operator --timeout="${OTEL_TIMEOUT}" >/dev/null 2>&1 || true
    
    kubectl get ns "${OTEL_SIMPLEST_NS}" >/dev/null 2>&1 || kubectl create ns "${OTEL_SIMPLEST_NS}" >/dev/null
    
    echo -e "${YELLOW}📊 Deploying Aspire Dashboard...${NC}"
    kubectl apply -f - <<EOF >/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: aspire-dashboard
  namespace: ${OTEL_SIMPLEST_NS}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: aspire-dashboard
  template:
    metadata:
      labels:
        app: aspire-dashboard
    spec:
      containers:
        - name: aspire-dashboard
          image: ${ASPIRE_DASHBOARD_IMAGE}
          ports:
            - containerPort: ${ASPIRE_DASHBOARD_PORT}
            - containerPort: 18889
          env:
            - name: DOTNET_DASHBOARD__OTLP__ENABLED
              value: "true"
            - name: DOTNET_DASHBOARD__OTLP__ENDPOINT
              value: "http://0.0.0.0:18889"
            - name: Dashboard__Otlp__AuthMode
              value: "Unsecured"
            - name: DOTNET_DASHBOARD_UNSECURED_ALLOW_ANONYMOUS
              value: "true"
---
apiVersion: v1
kind: Service
metadata:
  name: aspire-dashboard
  namespace: ${OTEL_SIMPLEST_NS}
spec:
  type: ClusterIP
  selector:
    app: aspire-dashboard
  ports:
    - name: http
      port: 80
      targetPort: ${ASPIRE_DASHBOARD_PORT}
    - name: otlp
      port: 18889
      targetPort: 18889
EOF
    
    
    
    echo -e "${YELLOW}🌐 Creating Ingress for Aspire Dashboard at https://${ASPIRE_INGRESS_HOST} ...${NC}"
  cat <<EOF | kubectl apply -f - >/dev/null
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: aspire-dashboard
  namespace: ${OTEL_SIMPLEST_NS}
  annotations:
    cert-manager.io/cluster-issuer: "${CA_ISSUER_NAME}"
spec:
  ingressClassName: ${ASPIRE_INGRESS_CLASS}
  tls:
    - hosts:
        - ${ASPIRE_INGRESS_HOST}
      secretName: ${ASPIRE_TLS_SECRET}
  rules:
    - host: ${ASPIRE_INGRESS_HOST}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: aspire-dashboard
                port:
                  number: 80
EOF
    
    
    echo -e "${YELLOW}🧪 Creating OpenTelemetryCollector connected to Aspire Dashboard...${NC}"
  kubectl apply -f - <<EOF >/dev/null
apiVersion: opentelemetry.io/v1beta1
kind: OpenTelemetryCollector
metadata:
  name: aspire-collector
  namespace: ${OTEL_SIMPLEST_NS}
spec:
  config:
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
          http:
            endpoint: 0.0.0.0:4318
    processors:
      memory_limiter:
        check_interval: 1s
        limit_percentage: 75
        spike_limit_percentage: 15
      batch:
        send_batch_size: 10000
        timeout: 10s
    exporters:
      otlp:
        endpoint: http://aspire-dashboard.${OTEL_SIMPLEST_NS}.svc.cluster.local:18889
        tls:
          insecure: true
      debug: {}
    service:
      telemetry:
        logs:
          level: info
      pipelines:
        traces:
          receivers: [otlp]
          processors: [memory_limiter, batch]
          exporters: [otlp, debug]
        metrics:
          receivers: [otlp]
          processors: [memory_limiter, batch]
          exporters: [otlp, debug]
        logs:
          receivers: [otlp]
          processors: [memory_limiter, batch]
          exporters: [otlp, debug]
EOF
    
    echo -e "${BLUE}⏳ Waiting for Aspire Dashboard...${NC}"
    kubectl -n "${OTEL_SIMPLEST_NS}" rollout status deploy/aspire-dashboard --timeout="${OTEL_TIMEOUT}" >/dev/null 2>&1 || true
    
    
    echo -e "${GREEN}✅ Aspire Dashboard and OpenTelemetry Collector installed.${NC}"

    echo -e "${YELLOW}📦 Applying ${HOME}/.kind/otel-plugin-extras/k8s (kustomize)...${NC}"
    kubectl apply -k "${HOME}/.kind/otel-plugin-extras/k8s/" >/dev/null 2>&1 || true
    echo -e "${GREEN}✅ Applied k8s manifests from ${HOME}/.kind/otel-plugin-extras/k8s/.${NC}"
}

otel_status(){
    need kubectl || return 1
    
    echo -e "${BLUE}🔎 Operator (${OTEL_NS}) deployments:${NC}"
    kubectl -n "${OTEL_NS}" get deploy,po 2>/dev/null || true
    echo
    
    echo -e "${BLUE}📊 Aspire (${OTEL_SIMPLEST_NS}) components:${NC}"
    kubectl -n "${OTEL_SIMPLEST_NS}" get deploy,svc,po 2>/dev/null || true
    echo
    
    echo -e "${BLUE}📦 OTel CRDs:${NC}"
    kubectl get crd | grep -E '^opentelemetrycollectors\.opentelemetry\.io' || true
    echo
}

otel_uninstall(){
    need helm || return 1
    need kubectl || return 1

    echo -e "${YELLOW}🗑️ Deleting ${HOME}/.kind/otel-plugin-extras/k8s (kustomize)...${NC}"
    kubectl delete -k "${HOME}/.kind/otel-plugin-extras/k8s/" >/dev/null 2>&1 || true
    
    kubectl -n "${OTEL_SIMPLEST_NS}" delete opentelemetrycollector aspire-collector >/dev/null 2>&1 || true
    kubectl -n "${OTEL_SIMPLEST_NS}" delete deploy aspire-dashboard >/dev/null 2>&1 || true
    kubectl -n "${OTEL_SIMPLEST_NS}" delete svc aspire-dashboard >/dev/null 2>&1 || true
    
    helm -n "${OTEL_NS}" uninstall "${OTEL_RELEASE}" >/dev/null 2>&1 || true

    kubectl delete ns "${OTEL_SIMPLEST_NS}" >/dev/null 2>&1 || true
    kubectl delete ns "${OTEL_NS}" >/dev/null 2>&1 || true
    
    echo -e "${GREEN}✅ Uninstall requested.${NC}"
}

otel_help(){
    echo -e "${BOLD}${CYAN}otel-operator.sh${NC}"
    echo
    echo "install     Install/upgrade OpenTelemetry Operator, Aspire Dashboard, and linked collector"
    echo "status      Show status for operator, collector, and dashboard"
    echo "uninstall   Remove all components"
    echo "help        Show this help"
}

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    export -f otel_install otel_status otel_uninstall otel_help
    return 0 2>/dev/null || true
fi

set -euo pipefail
case "${1:-install}" in
    install)    otel_install ;;
    status)     otel_status ;;
    uninstall)  otel_uninstall ;;
    help|-h|--help) otel_help ;;
    *) echo -e "${RED}❌ unknown: $1${NC}"; otel_help; exit 1 ;;
esac
