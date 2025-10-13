# 🧩 SuperKind — Local Kubernetes Pro Max

**SuperKind** gives you the *convenience of using Kubernetes with Rancher Desktop or Docker Desktop*, but with the *flexibility of Kind* — and more.
You get:

✅ **Opinionated convenience** — preconfigured defaults, plugins, and quick-start tools
⚙️ **Full flexibility** — still 100% Kind underneath
🪣 **Pull-through registry caching** — speed up local builds
📦 **Local registry integration** — push/pull without Docker Hub throttling
🔌 **Plugin-based extensibility** — `epinio`, `olm`, `keda`, `velero`, and more


> **Note:** SuperKind isn’t a tool for *learning* Kubernetes — it’s built for people who already use Kind  
> and are tired of re-writing the same setup scripts over and over.  
> It automates all the repetitive parts of bootstrapping a serious Kind cluster  
> with advanced features, plugins, and ready-to-use local infrastructure.


---

## 🧰 Prerequisites

Install these first:

| Tool        | Description                    |
| ----------- | ------------------------------ |
| **Kind**    | Local Kubernetes in Docker     |
| **Kubectl** | Kubernetes CLI                 |
| **Helm**    | Package manager for Kubernetes |

Verify:

```bash
kind version
kubectl version --client
helm version
```

**If you use Podman Desktop, then you can easily install all of these tools via the UI.**

---

## 🚀 Quick Start

```bash
git clone https://github.com/josephaw1022/SuperKind.git
cd SuperKind
chmod +x configure-scripts.sh
./configure-scripts.sh
```

You’ll then have commands like:

```bash
quick-kind --help
kind-plugin --help
kind-plugin epinio install
```

---

## ⚡ How It Works

SuperKind bootstraps a local developer environment with:

* **Kind**, **Helm**, and **Kubectl** prewired for local use
* **Plugin scripts** under `~/.kind/plugin`
* **Shell functions** auto-loaded from `~/.bashrc.d`

Each plugin adds specific functionality (OLM, Epinio, KEDA, Velero, etc.) for a richer local cluster experience.



---

## 🧩 Shell Integration

Make sure your `.bashrc` loads everything under `~/.bashrc.d`:

```bash
if [ -d ~/.bashrc.d ]; then
  for rc in ~/.bashrc.d/*; do
    [ -f "$rc" ] && . "$rc"
  done
fi
```

Reload:

```bash
source ~/.bashrc
```

---

## 🔁 Updating

Re-run anytime to refresh scripts:

```bash
./configure-scripts.sh
```

---

## ✅ Summary

After setup:

* `~/.bashrc.d` → Kind and plugin shell helpers
* `~/.kind/plugin` → Modular plugins (`epinio`, `olm`, `keda`, etc.)
* Kind, Helm, Kubectl ready for use

Spin up clusters, deploy workloads, and extend functionality — all locally and fast.