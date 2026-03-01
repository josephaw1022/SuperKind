# 🧩 SuperKind — Kind, but Super-Charged

**SuperKind** is a Go-based CLI tool that provides a "super-charged" local Kubernetes experience. It automates the setup of essential infrastructure (Ingress, Cert-Manager, Registries, Caching) using native Go SDKs for Kind, Docker, and Helm.

You get:

✅ **Opinionated convenience** — preconfigured defaults and native Go plugins.

⚙️ **Full flexibility** — still 100% Kind underneath. You can use the regular `kind` CLI if you want.

🧩 **Multi-node local clusters** — simulate realistic production topologies.

🪣 **Pull-through registry caching** — speed up local builds and avoid repeated remote pulls.

📦 **Local registry integration** — powered by a local **Zot** registry for fast, reliable image pushes and pulls without Docker Hub throttling.

🔌 **Native Go Plugins** — programmatically install `epinio`, `olm`, `keda`, `velero`, `argocd`, and more.

🌐 **Fallback UI** — automatically serves a friendly web landing page for any unmatched Ingress host on localhost and *.localhost.

🧱 **Works anywhere** — runs seamlessly with Docker Desktop and Podman Desktop.


> **SuperKind** is designed for developers who already use Kind, but want a smarter, faster local setup — with CA trust, ingress, registry caching, metrics, cert-manager, and more baked in.

---

## 🧰 Prerequisites

Install these first:

| Tool        | Description                |
| ----------- | -------------------------- |
| **Go**      | Version 1.24+              |
| **Docker**  | Container runtime          |
| **Kind**    | Local Kubernetes in Docker |
| **Kubectl** | Kubernetes CLI             |
| **Helm**    | Kubernetes package manager |

---

## 🚀 Quick Start

```bash
git clone https://github.com/josephaw1022/SuperKind.git
cd SuperKind
make install
```

This builds the `superkind` binary, installs it to `~/.local/bin`, and sets up your shell environment (alias: `sk`).

---

## ⚙️ Commands Overview

You can use either `superkind` or the shorter `sk` alias.

| Command                        | Description                                                        |
| ------------------------------ | ------------------------------------------------------------------ |
| `sk`                           | Show help or status of the default cluster                         |
| `sk up`                       | Create or update the default cluster (`sk-cluster`)                |
| `sk up [name]`                | Create a new cluster named `sk-[name]`                             |
| `sk status [name]`            | Show status of `sk-[name]`                                         |
| `sk delete [name]`            | Delete `sk-[name]`                                                 |
| `sk list`                     | List all SuperKind clusters (prefixed with `sk-`)                  |
| `sk plugin`                   | Manage native Go plugins (install, status, uninstall)              |

### 🧩 Example session

```bash
# Create a new cluster named sk-dev
sk up dev

# Install ArgoCD via native Go plugin
sk plugin argocd install

# Check cluster status
sk status dev

# List all SuperKind clusters
sk list

# Delete the cluster
sk delete dev
```

---

## 🛠 Development (Makefile)

The project uses a `Makefile` for standard tasks:

```bash
make build    # Build binary to bin/superkind
make test     # Run unit tests
make install  # Install to ~/.local/bin and setup aliases
make tidy     # Tidy Go modules
make clean    # Remove build artifacts
```

---

## 🧱 Architecture

SuperKind bootstraps a full local environment using native Go SDKs:

* **Kind cluster** with multiple nodes and prewired registry mirrors.
* **Native Root CA** generation (no `openssl` CLI dependencies).
* **Cert-Manager** and a local Root CA for HTTPS ingress.
* **Ingress-NGINX** preconfigured with NodePort **30080 / 30443**.
* **[Zot](https://zotregistry.dev/) based local registry** (`localhost:5001`).
* **Pull-through cache registries** for `docker.io`, `quay.io`, `ghcr.io`, and `mcr.microsoft.com`.
* **Prometheus stack** for built-in metrics and observability.
* **Native Go Plugins** — Programmatic installation logic for various K8s tools.

Everything is modular, idempotent, and executed via Go code.

---

## ✅ Summary

Run `sk up` to spin up clusters, `sk list` to list them, and `sk delete` to clean them up — all locally, fast, and fully automated.
