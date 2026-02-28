# SuperKind — Architectural & Instructional Context

SuperKind is an opinionated, plugin-based wrapper for [kind](https://kind.sigs.k8s.io/) (Kubernetes in Docker). It provides a "super-charged" local Kubernetes experience by automating the setup of essential infrastructure (Ingress, Cert-Manager, Registries, Caching) and offering a modular plugin system for extending cluster capabilities.

## 🏗️ Core Architecture

- **CLI Layer**: 
    - `qk` (alias for `quick-kind`): Manages the lifecycle of SuperKind clusters (prefixed with `qk-`).
    - `kind-plugin`: Manages modular extensions (ArgoCD, OTEL, KEDA, etc.).
- **Infrastructure Layer**:
    - **Kind**: The underlying Kubernetes engine.
    - **Local Registry**: [Zot](https://zotregistry.dev/) running at `localhost:5001`.
    - **Pull-through Caching**: Local `registry:2` instances proxying `docker.io`, `quay.io`, `ghcr.io`, and `mcr.microsoft.com`.
    - **TLS/PKI**: Automated local Root CA generation and integration with Cert-Manager.
- **Service Layer**:
    - **Ingress-NGINX**: Preconfigured to listen on ports 80/443 (via NodePorts 30080/30443).
    - **Kube-Prometheus-Stack**: Installed by default for observability.
    - **Fallback UI**: A default landing page for unmatched ingress hosts.

## 🚀 Key Workflows

### 1. Initialization
The project must be initialized to install shell helpers and plugin scripts.
```bash
./configure-scripts.sh
```
*This copies scripts to `~/.bashrc.d/` and `~/.kind/`, and sets up the environment.*

### 2. Cluster Management
- **Create/Update**: `qk up` (creates `qk-quick-cluster`) or `qk up -n mycluster`.
- **Status**: `qk status` or `qk status -n mycluster`.
- **List**: `qk -l` (lists only `qk-` prefixed clusters).
- **Delete**: `qk -d` or `qk -d mycluster`.

### 3. Plugin Management
Plugins are located in `~/.kind/plugin/`. Use the `kind-plugin` command to manage them:
- **List plugins**: `kind-plugin` (no args).
- **Install**: `kind-plugin <name> install` (e.g., `kind-plugin argocd install`).
- **Status**: `kind-plugin <name> status`.
- **Uninstall**: `kind-plugin <name> uninstall`.

### 4. OpenTelemetry Extras (.NET)
The `src/otel-plugin-extras/` directory contains a .NET `simple-api` used for testing OTEL integration.
- **Build/Watch**: Use the `Taskfile.yaml` inside `src/otel-plugin-extras/`.
  ```bash
  task watch       # Run with dotnet watch
  task build-image # Build and push container
  ```

## 🛠️ Development Conventions

- **Idempotency**: All scripts (shell and K8s manifests) should be idempotent.
- **Shell Standards**: Use `set -euo pipefail` in bash scripts.
- **Registry Usage**: Always prefer the local Zot registry (`localhost:5001`) or the pull-through caches for speed and to avoid throttling.
- **TLS**: Use the `quick-kind-ca` ClusterIssuer for all internal service certificates.
- **Manifests**: Use Kustomize for complex application deployments (see `src/otel-plugin-extras/k8s`).

## 📁 Key Directories & Files

- `src/kind-quick.sh`: Implementation of the `qk` command.
- `src/kind-plugins.sh`: Implementation of the `kind-plugin` command.
- `src/plugins/`: Source of all plugin scripts.
- `src/otel-plugin-extras/`: .NET source code and K8s manifests for OTEL testing.
- `configure-scripts.sh`: Installer script.
- `~/.kind/`: Home for persistent configuration and resources (fallback UI, extra assets).

## ⚠️ Important Notes
- **Podman/Docker**: SuperKind works with both, but requires the `docker` CLI or alias to be present.
- **Shell Sourcing**: After running `configure-scripts.sh`, ensure `~/.bashrc` sources `~/.bashrc.d/*.sh`.
- **Naming**: Only clusters starting with `qk-` are managed by SuperKind tools.
