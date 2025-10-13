# 🧩 SuperKind — Kind, but Super-Charged

**SuperKind** gives you the *convenience of Docker Desktop or Podman Desktop*, but with the *flexibility and power of Kind* — and more.

You get:

✅ **Opinionated convenience** — preconfigured defaults, plugins, and quick-start tools.

⚙️ **Full flexibility** — still 100% Kind underneath. You can use the regular `kind` CLI if you want.

🧩 **Multi-node local clusters** — simulate realistic production topologies.

🪣 **Pull-through registry caching** — speed up local builds and avoid repeated remote pulls.

📦 **Local registry integration** — push and pull without Docker Hub throttling.

🔌 **Plugin-based extensibility** — add things like `epinio`, `olm`, `keda`, `velero`, or anything Helm-based.

🧱 **Works anywhere** — runs seamlessly with Docker Desktop and Podman Desktop. Users using Rancher Desktop on Windows may have issues running Kind in general so this may not work.

> **SuperKind** is designed for developers who already use Kind, but want a smarter, faster local setup — with CA trust, ingress, registry caching, metrics, cert-manager, and more baked in.

---

## 🧰 Prerequisites

Install these first:

| Tool        | Description                |
| ----------- | -------------------------- |
| **Kind**    | Local Kubernetes in Docker |
| **Kubectl** | Kubernetes CLI             |
| **Helm**    | Kubernetes package manager |

Verify installation:

```bash
kind version
kubectl version --client
helm version
```

If you’re using **Podman Desktop**, you can install all of these directly from its UI.

---

## 🚀 Quick Start

```bash
git clone https://github.com/josephaw1022/SuperKind.git
cd SuperKind
chmod +x configure-scripts.sh
./configure-scripts.sh
```

This sets up your shell environment and makes `quick-kind` (alias: `qk`) available globally.

---

## ⚙️ Commands Overview

| Command                | Description                                                        |
| ---------------------- | ------------------------------------------------------------------ |
| `qk`                   | Show status of the default SuperKind cluster (`qk-quick-cluster`)  |
| `qk up`                | Create or update the default cluster                               |
| `qk up -n dev`         | Create a new cluster named `qk-dev`                                |
| `qk status -n dev`     | Show status of `qk-dev`                                            |
| `qk -d`                | Delete the default cluster (`qk-quick-cluster`)                    |
| `qk -d dev`            | Delete `qk-dev`                                                    |
| `qk -l` or `qk --list` | List all SuperKind clusters (any Kind cluster prefixed with `qk-`) |
| `qk --help`            | Show full command reference                                        |

### 🧩 Example session

```bash
# Create a new cluster named qk-dev
qk up -n dev

# Check its status
qk status -n dev

# List all SuperKind clusters
qk -l

# Delete the cluster
qk -d dev
```

---

## 🧠 Behavior Summary

* **Cluster names are always prefixed with `qk-`**
  The default cluster is now `qk-quick-cluster`.
  All user-created clusters follow the same naming rule.

* **Running `qk` alone only shows status**
  To actually create or rebuild, run `qk up`.

* **You can manage multiple local clusters easily**
  Use different names with `-n` or `--name`:

  ```bash
  qk up -n demo
  qk status -n demo
  qk -d demo
  ```

* **List view shows only SuperKind clusters**
  The list filter ignores any Kind clusters not starting with `qk-`.

---

## 🧩 Shell Integration

SuperKind installs shell helpers into `~/.bashrc.d`.
Make sure your `.bashrc` sources them automatically:

```bash
if [ -d ~/.bashrc.d ]; then
  for rc in ~/.bashrc.d/*; do
    [ -f "$rc" ] && . "$rc"
  done
fi
```

Reload your shell:

```bash
source ~/.bashrc
```

Then confirm `qk` works:

```bash
qk --help
```

---

## 🧱 Architecture

When you run `qk up`, SuperKind bootstraps:

* **Kind cluster** with multiple nodes and prewired registry mirrors
* **Cert-Manager** and a local Root CA for HTTPS ingress
* **Ingress-NGINX** preconfigured with NodePort **30080 / 30443**
* **[Zot](https://zotregistry.dev/v2.1.8/) based local registry** — a fast, OCI-compliant registry with full ORAS artifact support (`localhost:5001`)
* **Pull-through cache registries** for faster image pulls from:
  * `docker.io` → cached via `dockerhub-proxy-cache`
  * `quay.io` → cached via `quay-proxy-cache`
  * `ghcr.io` → cached via `ghcr-proxy-cache`
  * `mcr.microsoft.com` → cached via `mcr-proxy-cache`
* **Prometheus stack** for built-in metrics and observability
* **Optional plugin extensions** — `OLM`, `Epinio`, `KEDA`, `Velero`, and more (Helm-based)


Everything is modular, idempotent, and easy to rerun.

---

## 🔁 Updating

To refresh scripts or reconfigure shell integration, rerun:

```bash
./configure-scripts.sh
```

---

## ✅ Summary

After setup, you’ll have:

| Path                | Purpose                                                    |
| ------------------- | ---------------------------------------------------------- |
| `~/.bashrc.d`       | SuperKind shell helpers (e.g. `quick-kind`, `kind-plugin`) |
| `~/.kind/plugin`    | Modular plugin scripts (`epinio`, `olm`, `keda`, etc.)     |
| Local Kind clusters | Named `qk-*`, managed with `qk` CLI                        |

Run `qk up` to spin up clusters, `qk -l` to list them, and `qk -d` to clean them up — all locally, fast, and fully automated.
