# 🧩 SuperKind Setup Guide

This repository provides a lightweight developer bootstrap for local **Kind**, **Helm**, and **Kubectl** workflows with plugin-based extensions such as `quick-kind`, `epinio`, and `olm`.

---

## 📋 Prerequisites

Before running any scripts, ensure you have the following installed and available in your `PATH`:

| Tool | Description | Install Command (Linux) |
|------|--------------|--------------------------|
| **Kind** | Kubernetes-in-Docker cluster tool | `curl -Lo ./kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64 && chmod +x ./kind && sudo mv ./kind /usr/local/bin/kind` |
| **Kubectl** | Kubernetes CLI | `sudo apt install -y kubectl` or use your distro’s package manager |
| **Helm** | Kubernetes package manager | `curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash` |

Verify each one:
```bash
kind version
kubectl version --client
helm version
````

---

## 🏗️ Shell Configuration

You’ll need a `~/.bashrc.d` folder so scripts can be modularized cleanly.

1. Create the folder (if it doesn’t exist):

   ```bash
   mkdir -p ~/.bashrc.d
   ```

2. Add the following snippet **to the bottom of your `~/.bashrc`** (if it isn’t already there):

   ```bash
   # User specific aliases and functions
   if [ -d ~/.bashrc.d ]; then
       for rc in ~/.bashrc.d/*; do
           if [ -f "$rc" ]; then
               . "$rc"
           fi
       done
   fi
   unset rc
   ```

   This ensures all helper scripts in `~/.bashrc.d/` are automatically loaded into your shell each time you open a terminal.

3. Apply the changes:

   ```bash
   source ~/.bashrc
   ```

---

## ⚙️ Configure Scripts

From the root of this repository, run:

```bash
chmod +x configure-scripts.sh
./configure-scripts.sh
```

This will:

* Create or update your `~/.bashrc.d` and `~/.kind/plugin` directories.
* Copy Kind-related helper scripts into `~/.bashrc.d/`.
* Copy plugin scripts (like `epinio.sh` and `olm.sh`) into `~/.kind/plugin/`.
* Make all of them executable.

---

## 🚀 Usage

After installation, you’ll have access to the following commands:

```bash
quick-kind --help        # Manage your Kind cluster quickly
kind-plugin --help       # List and run plugins
kind-plugin epinio       # Manage the Epinio plugin
kind-plugin olm          # Manage the OLM plugin
```

---

## 🧹 Updating Scripts

If you make updates in the `src/` directory, simply rerun:

```bash
./configure-scripts.sh
```

This will override the old versions with the latest copies.

---

## ✅ Summary

**After setup:**

* `~/.bashrc.d` holds your shell extensions (`kind-quick.sh`, `kind-plugins.sh`, etc.).
* `~/.kind/plugin` holds your plugin scripts (`epinio.sh`, `olm.sh`, etc.).
* Kind, Kubectl, and Helm must be installed.
* The `.bashrc` snippet ensures automatic sourcing.

You’re now ready to spin up local clusters, deploy services, and extend functionality with plugins.
