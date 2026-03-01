# SuperKind — Architectural & Instructional Context

SuperKind is a Go-based, plugin-driven wrapper for [kind](https://kind.sigs.k8s.io/) (Kubernetes in Docker). It provides a "super-charged" local Kubernetes experience by automating the setup of essential infrastructure (Ingress, Cert-Manager, Registries, Caching) using native Go SDKs.

## 🏗️ Core Architecture

- **CLI Layer**: 
    - `superkind` (alias: `sk`): A Go binary built with Cobra. Manages the lifecycle of SuperKind clusters (prefixed with `sk-`).
    - **Native Plugins**: Integrated Go logic for modular extensions (ArgoCD, OTEL, KEDA, etc.), managed via `sk plugin`.
- **Infrastructure Layer**:
    - **Kind SDK**: Orchestrates the underlying Kubernetes engine programmatically.
    - **Docker SDK**: Manages the local [Zot](https://zotregistry.dev/) registry (`localhost:5001`) and pull-through caching (`registry:2` instances).
    - **Native PKI**: Automated local Root CA generation using Go's `crypto/x509` package.
- **Service Layer (Helm SDK)**:
    - **Ingress-NGINX**: Programmatically installed via Helm Go SDK.
    - **Kube-Prometheus-Stack**: Installed by default for observability.
    - **Cert-Manager**: Manages internal TLS using the `superkind-ca` ClusterIssuer.

## 🚀 Key Workflows

### 1. Installation
The project uses a `Makefile` for building and installation.
```bash
make install
```
*This builds the binary to `bin/superkind`, copies it to `~/.local/bin`, and sets up the shell environment in `~/.bashrc.d/superkind.sh`.*

### 2. Cluster Management
- **Create/Update**: `sk up` (creates `sk-cluster`) or `sk up [name]`.
- **Status**: `sk status [name]`.
- **List**: `sk list` (lists only `sk-` prefixed clusters).
- **Delete**: `sk delete [name]`.

### 3. Plugin Management
Plugins are implemented as Go structs satisfying the `Plugin` interface.
- **List plugins**: `sk plugin` (no args).
- **Install**: `sk plugin <name> install`.
- **Status**: `sk plugin <name> status`.
- **Uninstall**: `sk plugin <name> uninstall`.

## 🛠️ Development Conventions

- **Idempotency**: All Go logic (especially SDK calls) MUST be idempotent.
- **SDK Usage**: Always prefer native Go SDKs (`sigs.k8s.io/kind`, `github.com/docker/docker/client`, `helm.sh/helm/v3/pkg/action`) over `os/exec` wrappers.
- **Testing**:
    - Every new feature or plugin MUST include unit tests in the same package.
    - Use `go test ./...` to verify the entire project.
- **Registry Usage**: Always prefer the local Zot registry (`localhost:5001`) or the pull-through caches for speed and to avoid throttling.
- **TLS**: Use the `superkind-ca` ClusterIssuer for all internal service certificates.

## 📁 Key Directories & Files

- `cmd/superkind/`: CLI entry point and command definitions (Cobra).
- `pkg/config/`: Global configuration logic and engine mapping.
- `pkg/engine/`: Core orchestration logic using native SDKs (Docker, Kind, K8s, Helm).
- `pkg/plugin/`: Native Go plugin implementations and manager.
- `Makefile`: Central tool for build, test, and install lifecycles.
- `~/.kind/`: Home for persistent configuration and resources (fallback UI, extra assets).

## ⚠️ Important Notes
- **Go Version**: Requires Go 1.24+ for building.
- **Docker**: Requires the Docker daemon to be running and the `docker` CLI or alias to be present for Kind compatibility.
- **Shell Sourcing**: After `make install`, ensure `~/.bashrc` sources `~/.bashrc.d/*.sh`.
- **Naming**: Only clusters starting with `sk-` are managed by SuperKind tools.
