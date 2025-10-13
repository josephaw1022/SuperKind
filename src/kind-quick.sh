quick-kind() {
    
    # Color definitions
    local RED='\033[0;31m'
    local GREEN='\033[0;32m'
    local YELLOW='\033[0;33m'
    local BLUE='\033[0;34m'
    local MAGENTA='\033[0;35m'
    local CYAN='\033[0;36m'
    local WHITE='\033[0;37m'
    local BOLD='\033[1m'
    local NC='\033[0m' # No Color
    
    local CLUSTER_NAME="${CLUSTER_NAME:-quick-cluster}"
    local CA_DIR="${CA_DIR:-$HOME/.local/share/quick-kind/ca}"
    local CA_KEY="${CA_KEY:-$CA_DIR/rootCA.key}"
    local CA_CRT="${CA_CRT:-$CA_DIR/rootCA.crt}"
    local CA_CN="${CA_CN:-Quick Kind Local CA}"
    local CA_SECRET_NAME="${CA_SECRET_NAME:-quick-kind-ca}"
    local CA_ISSUER_NAME="${CA_ISSUER_NAME:-quick-kind-ca}"
    
    # registry/caches (override if you want different ports/names)
    local LOCAL_REGISTRY_NAME="${LOCAL_REGISTRY_NAME:-local-registry}"
    local LOCAL_REGISTRY_HOST_PORT="${LOCAL_REGISTRY_HOST_PORT:-5001}"   # localhost:5001 -> local push/pull
    local DOCKERHUB_CACHE_NAME="${DOCKERHUB_CACHE_NAME:-dockerhub-proxy-cache}"
    local QUAY_CACHE_NAME="${QUAY_CACHE_NAME:-quay-proxy-cache}"
    local GHCR_CACHE_NAME="${GHCR_CACHE_NAME:-ghcr-proxy-cache}"
    local MCR_CACHE_NAME="${MCR_CACHE_NAME:-mcr-proxy-cache}"
    
    need() { command -v "$1" >/dev/null 2>&1 || { echo -e "${RED}❌ missing dependency: $1${NC}"; return 1; }; }
    
    show_help() {
        echo -e "${BOLD}${CYAN}Usage: quick-kind [option]${NC}"
        echo
        echo -e "${BOLD}Options:${NC}"
        echo -e "  ${GREEN}--help${NC}        Show this help message"
        echo -e "  ${GREEN}--status${NC}      Show Kind cluster and Helm chart status"
        echo -e "  ${GREEN}--teardown${NC}    Delete Kind cluster"
        echo -e "  ${GREEN}(no args)${NC}     Create Kind cluster + local registries + cert-manager + ingress-nginx"
    }
    
    teardown() {
        echo -e "${YELLOW}🧹 Deleting kind cluster '${CLUSTER_NAME}'...${NC}"
        kind delete cluster --name "${CLUSTER_NAME}" || echo -e "${YELLOW}Cluster not found${NC}"
        # Leave caches/registry running so layers stay warm; comment out below if you want them gone.
        echo -e "${CYAN}ℹ️ Leaving local registry & caches running (for speed).${NC}"
        echo -e "${GREEN}🧼 Cleanup complete.${NC}"
    }
    
    status() {
        if ! kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
            echo -e "${RED}❌ Kind cluster '${CLUSTER_NAME}' not found.${NC}"
            return 1
        fi
        echo -e "${GREEN}✅ Kind cluster '${CLUSTER_NAME}' is running.${NC}"
        
        echo -e "${BLUE}🗄️  Local registry & caches (docker ps):${NC}"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(^${LOCAL_REGISTRY_NAME}$|${DOCKERHUB_CACHE_NAME}|${QUAY_CACHE_NAME}|${GHCR_CACHE_NAME}|${MCR_CACHE_NAME})" || true
        echo
        
        echo -e "${BLUE}🔍 Helm releases:${NC}"
        helm list -A || echo -e "${YELLOW}No Helm releases found.${NC}"
        echo
        echo -e "${BLUE}📦 Cert-manager pods:${NC}"
        kubectl get pods -n cert-manager 2>/dev/null || true
        echo
        echo -e "${BLUE}🌐 Ingress-nginx pods:${NC}"
        kubectl get pods -n ingress-nginx 2>/dev/null || true
        echo
        echo -e "${BLUE}🔐 ClusterIssuers:${NC}"
        kubectl get clusterissuers 2>/dev/null || true
    }
    
    ensure_local_ca() {
        need openssl || return 1
        mkdir -p "${CA_DIR}"
        
        if [[ -s "${CA_KEY}" && -s "${CA_CRT}" ]]; then
            echo -e "${CYAN}🔐 Reusing existing local CA at ${CA_DIR}${NC}"
        else
            echo -e "${YELLOW}🔐 Generating local Root CA...${NC}"
            openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
            -subj "/CN=${CA_CN}/O=Quick Kind/OU=Dev" \
            -keyout "${CA_KEY}" -out "${CA_CRT}" >/dev/null 2>&1
            chmod 600 "${CA_KEY}"
            echo -e "${GREEN}✅ Root CA created: ${CA_CRT}${NC}"
        fi
        
        # if [[ -f /etc/os-release ]] && grep -qiE 'almalinux|rhel|centos|fedora' /etc/os-release; then
        #     if command -v sudo >/dev/null 2>&1; then
        #         local anchor="/etc/pki/ca-trust/source/anchors/quick-kind-rootCA.crt"
        #         if ! sudo test -f "${anchor}" || ! cmp -s "${CA_CRT}" "${anchor}"; then
        #             echo -e "${YELLOW}🔗 Installing CA into system trust (AlmaLinux/RHEL/Fedora)...${NC}"
        #             sudo cp "${CA_CRT}" "${anchor}"
        #             sudo update-ca-trust extract
        #             echo -e "${GREEN}✅ System trust updated.${NC}"
        #         else
        #             echo -e "${CYAN}🔗 CA already present in system trust.${NC}"
        #         fi
        #     else
        #         echo -e "${BLUE}ℹ️ 'sudo' not found; skipping system trust install.${NC}"
        #     fi
        # fi
    }
    
    ensure_local_kind_registry() {
        if [ "$(docker inspect -f '{{.State.Running}}' "${LOCAL_REGISTRY_NAME}" 2>/dev/null || true)" != "true" ]; then
            echo -e "${YELLOW}🗄️  creating local registry (push/pull) on localhost:${LOCAL_REGISTRY_HOST_PORT}...${NC}"
            docker run -d --restart=always \
            --name "${LOCAL_REGISTRY_NAME}" \
            -p "127.0.0.1:${LOCAL_REGISTRY_HOST_PORT}:5000" \
            registry:2 >/dev/null
        else
            echo -e "${CYAN}🗄️  local registry already running.${NC}"
        fi
    }
    
    setup_dockerhub_pullthrough_cache() {
        if [ "$(docker inspect -f '{{.State.Running}}' "${DOCKERHUB_CACHE_NAME}" 2>/dev/null || true)" != "true" ]; then
            echo -e "${YELLOW}📦 creating Docker Hub pull-through cache on :5000...${NC}"
            
            local USERNAME=""; local PASSWORD=""
            
            echo -n "Docker Hub username (leave blank for anonymous): "
            read -r USERNAME
            if [ -n "$USERNAME" ]; then
                echo -n "Docker Hub token/password (visible as you type): "
                read -r PASSWORD
            fi
            
            if [ -n "$USERNAME" ] && [ -n "$PASSWORD" ]; then
                docker run -d --restart=always \
                --name "${DOCKERHUB_CACHE_NAME}" \
                -e REGISTRY_PROXY_REMOTEURL="https://registry-1.docker.io" \
                -e REGISTRY_PROXY_USERNAME="$USERNAME" \
                -e REGISTRY_PROXY_PASSWORD="$PASSWORD" \
                --network kind \
                registry:2 >/dev/null
                echo -e "${GREEN}✅ Docker Hub cache (authenticated) created.${NC}"
            else
                docker run -d --restart=always \
                --name "${DOCKERHUB_CACHE_NAME}" \
                -p "5000:5000" \
                -e REGISTRY_PROXY_REMOTEURL="https://registry-1.docker.io" \
                --network kind \
                registry:2 >/dev/null
                echo -e "${GREEN}✅ Docker Hub cache (anonymous) created.${NC}"
            fi
        else
            echo -e "${CYAN}📦 dockerhub cache already running.${NC}"
        fi
    }
    
    
    setup_quay_pullthrough_cache() {
        if [ "$(docker inspect -f '{{.State.Running}}' "${QUAY_CACHE_NAME}" 2>/dev/null || true)" != "true" ]; then
            echo -e "${YELLOW}📦 creating quay.io pull-through cache on :5002...${NC}"
            docker run -d --restart=always \
            --name "${QUAY_CACHE_NAME}" \
            -e REGISTRY_PROXY_REMOTEURL="https://quay.io" \
            --network kind \
            registry:2 >/dev/null
        else
            echo -e "${CYAN}📦 quay cache already running.${NC}"
        fi
    }
    
    setup_ghcr_pullthrough_cache() {
        if [ "$(docker inspect -f '{{.State.Running}}' "${GHCR_CACHE_NAME}" 2>/dev/null || true)" != "true" ]; then
            echo -e "${YELLOW}📦 creating ghcr.io pull-through cache on :5003...${NC}"
            docker run -d --restart=always \
            --name "${GHCR_CACHE_NAME}" \
            -e REGISTRY_PROXY_REMOTEURL="https://ghcr.io" \
            --network kind \
            registry:2 >/dev/null
        else
            echo -e "${CYAN}📦 ghcr cache already running.${NC}"
        fi
    }
    
    setup_mcr_pullthrough_cache() {
        if [ "$(docker inspect -f '{{.State.Running}}' "${MCR_CACHE_NAME}" 2>/dev/null || true)" != "true" ]; then
            echo -e "${YELLOW}📦 creating mcr.microsoft.com pull-through cache on :5004...${NC}"
            docker run -d --restart=always \
            --name "${MCR_CACHE_NAME}" \
            -e REGISTRY_PROXY_REMOTEURL="https://mcr.microsoft.com" \
            --network kind \
            registry:2 >/dev/null
        else
            echo -e "${CYAN}📦 mcr cache already running.${NC}"
        fi
    }
    
    
    ensure_registry_k8s_config() {
        # Advertise local-registry in cluster per KIND docs
    kubectl apply -f - >/dev/null 2>&1 <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${LOCAL_REGISTRY_HOST_PORT}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF
    }
    
    ensure_kind_cluster() {
        echo -e "${YELLOW}▶ creating kind cluster '${CLUSTER_NAME}' (if needed)...${NC}"
        if ! kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
      cat <<EOF | kind create cluster --name "${CLUSTER_NAME}" --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4

# Pre-wire containerd mirrors to our local registry & caches
containerdConfigPatches:
  - |-
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:${LOCAL_REGISTRY_HOST_PORT}"]
      endpoint = ["http://${LOCAL_REGISTRY_NAME}:5000"]
  - |-
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
      endpoint = ["http://${DOCKERHUB_CACHE_NAME}:5000"]
  - |-
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."quay.io"]
      endpoint = ["http://${QUAY_CACHE_NAME}:5000"]
  - |-
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."ghcr.io"]
      endpoint = ["http://${GHCR_CACHE_NAME}:5000"]
  - |-
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."mcr.microsoft.com"]
      endpoint = ["http://${MCR_CACHE_NAME}:5000"]

nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30080
    hostPort: 80
    protocol: TCP
  - containerPort: 30443
    hostPort: 443
    protocol: TCP
- role: worker
EOF
        else
            echo -e "${CYAN}… cluster already exists; skipping create.${NC}"
        fi
    }
    
    # For clusters created earlier WITHOUT patches, write hosts.toml post-hoc (safe to re-run)
    configure_kind_nodes_for_local_registry() {
        for node in $(kind get nodes --name "$CLUSTER_NAME" 2>/dev/null); do
            echo -e "${BLUE}🔧 patching containerd mirrors on ${node}${NC}"
            
            docker exec "$node" mkdir -p /etc/containerd/certs.d/localhost:${LOCAL_REGISTRY_HOST_PORT}
      docker exec -i "$node" bash -c "cat > /etc/containerd/certs.d/localhost:${LOCAL_REGISTRY_HOST_PORT}/hosts.toml" <<EON
[host."http://${LOCAL_REGISTRY_NAME}:5000"]
EON
            
            for pair in \
            "docker.io ${DOCKERHUB_CACHE_NAME}" \
            "quay.io ${QUAY_CACHE_NAME}" \
            "ghcr.io ${GHCR_CACHE_NAME}" \
            "mcr.microsoft.com ${MCR_CACHE_NAME}"; do
                set -- $pair
                docker exec "$node" mkdir -p /etc/containerd/certs.d/$1
        docker exec -i "$node" bash -c "cat > /etc/containerd/certs.d/$1/hosts.toml" <<EON
[host."http://$2:5000"]
EON
            done
            
            # reload containerd (kind nodes use systemd)
            # docker exec "$node" bash -lc 'systemctl restart containerd' >/dev/null 2>&1 || true
        done
    }
    
    ensure_cert_manager() {
        if helm status cert-manager -n cert-manager >/dev/null 2>&1; then
            echo -e "${GREEN}✅ cert-manager already installed; skipping.${NC}"
        else
            echo -e "${YELLOW}📦 installing cert-manager...${NC}"
            helm upgrade --install cert-manager oci://quay.io/jetstack/charts/cert-manager \
            --version v1.18.2 \
            --namespace cert-manager \
            --create-namespace \
            --set crds.enabled=true
        fi
        echo -e "${BLUE}⏳ waiting for cert-manager pods...${NC}"
        kubectl rollout status deploy/cert-manager -n cert-manager --timeout=180s || true
        kubectl rollout status deploy/cert-manager-webhook -n cert-manager --timeout=180s || true
        kubectl rollout status deploy/cert-manager-cainjector -n cert-manager --timeout=180s || true
    }
    
    ensure_ca_secret_and_issuer() {
        echo -e "${YELLOW}🔐 Ensuring CA secret & ClusterIssuer...${NC}"
        if kubectl -n cert-manager get secret "${CA_SECRET_NAME}" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ CA secret '${CA_SECRET_NAME}' already exists; skipping.${NC}"
        else
            kubectl -n cert-manager create secret tls "${CA_SECRET_NAME}" \
            --cert="${CA_CRT}" --key="${CA_KEY}"
            echo -e "${GREEN}✅ Created secret cert-manager/${CA_SECRET_NAME}.${NC}"
        fi
        
        if kubectl get clusterissuer "${CA_ISSUER_NAME}" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ ClusterIssuer '${CA_ISSUER_NAME}' already exists; skipping.${NC}"
        else
      cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ${CA_ISSUER_NAME}
spec:
  ca:
    secretName: ${CA_SECRET_NAME}
EOF
            echo -e "${GREEN}✅ ClusterIssuer '${CA_ISSUER_NAME}' created.${NC}"
        fi
    }
    
    ensure_ingress_nginx() {
        if helm status ingress-nginx -n ingress-nginx >/dev/null 2>&1; then
            echo -e "${GREEN}🌐 ingress-nginx already installed; skipping.${NC}"
        else
            echo -e "${YELLOW}🌐 installing ingress-nginx...${NC}"
            helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx >/dev/null 2>&1 || true
            helm repo update >/dev/null 2>&1 || true
      cat <<'EOF' | helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
        --namespace ingress-nginx \
        --create-namespace \
        --values -
controller:
  ingressClassResource:
    default: true
  service:
    type: NodePort
    nodePorts:
      http: 30080
      https: 30443
EOF
        fi
        echo -e "${BLUE}⏳ waiting for ingress-nginx rollout...${NC}"
        kubectl rollout status deploy/ingress-nginx-controller -n ingress-nginx --timeout=300s || true
    }
    
    
    install_prometheus_stack() {
        echo "INFO" "Installing kube-prometheus-stack into kube-system"
        echo "Installing kube-prometheus-stack into kube-system..."
        
        helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
        helm repo update >/dev/null 2>&1 || true
        
        helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
        -n kube-system \
        --version 77.13.0 \
        --atomic \
        --create-namespace \
    -f /dev/stdin <<EOF
prometheus:
  prometheusSpec: {}

alertmanager:
  alertmanagerSpec: {}
EOF
        
        log "INFO" "kube-prometheus-stack installation complete"
    }
    
    
    main() {
        need kind || return 1
        need kubectl || return 1
        need helm || return 1
        need docker || { echo -e "${RED}❌ docker required for local registries/caches${NC}"; return 1; }
        ensure_local_ca
        ensure_local_kind_registry
        setup_dockerhub_pullthrough_cache
        setup_quay_pullthrough_cache
        setup_ghcr_pullthrough_cache
        setup_mcr_pullthrough_cache
        ensure_kind_cluster
        configure_kind_nodes_for_local_registry
        ensure_registry_k8s_config
        install_prometheus_stack
        ensure_cert_manager
        ensure_ca_secret_and_issuer
        ensure_ingress_nginx
        
        echo -e "${GREEN}✅ done.${NC}"
        echo -e "${CYAN}- HTTP  -> http://localhost${NC}"
        echo -e "${CYAN}- HTTPS -> https://localhost${NC}"
        echo -e "${CYAN}- Local registry -> localhost:${LOCAL_REGISTRY_HOST_PORT}${NC}"
        echo -e "${CYAN}- Mirrors -> docker.io, quay.io, ghcr.io, mcr.microsoft.com via caches${NC}"
        echo -e "${CYAN}- CA    -> ${CA_CRT}${NC}"
        echo -e "${CYAN}- Issuer-> ClusterIssuer \"${CA_ISSUER_NAME}\"${NC}"
        echo -e "${YELLOW}(use Ingress annotation: cert-manager.io/cluster-issuer: \"${CA_ISSUER_NAME}\")${NC}"
    }
    
    case "${1:-}" in
        --help) show_help ;;
        --teardown) teardown ;;
        --status) status ;;
        "") main ;;
        *) echo -e "${RED}❌ Unknown option: $1${NC}"; show_help; return 1 ;;
    esac
}
