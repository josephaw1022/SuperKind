#!/usr/bin/env bash
set -euo pipefail

BASHRC_D="${HOME}/.bashrc.d"
KIND_DIR="${HOME}/.kind"
KIND_PLUGIN_DIR="${HOME}/.kind/plugin"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/src" && pwd)"

echo "📁 Ensuring destination directories exist..."
mkdir -p "${BASHRC_D}" "${KIND_PLUGIN_DIR}"

echo "⚙️  Copying scripts..."
cp -f "${SRC_DIR}/kind-quick.sh" "${BASHRC_D}/"
cp -f "${SRC_DIR}/kind-plugins.sh" "${BASHRC_D}/"
cp -f "${SRC_DIR}/plugins/"*.sh "${KIND_PLUGIN_DIR}/"
cp -f "${SRC_DIR}/fallback.yaml" "${KIND_DIR}/"
cp -f "${SRC_DIR}/index.html" "${KIND_DIR}/index.html"

echo "🔒 Making everything executable..."
chmod +x "${BASHRC_D}"/*.sh "${KIND_PLUGIN_DIR}"/*.sh
chmod 644 "${KIND_DIR}/fallback.yaml"
chmod 644 "${KIND_DIR}/index.html"

echo "✅ All scripts installed and executable."
echo
echo "🧩 Installed to:"
echo "  ${BASHRC_D}"
echo "  ${KIND_PLUGIN_DIR}"
echo
echo "💡 Make sure your ~/.bashrc includes:"
echo "    for f in ~/.bashrc.d/*.sh; do source \"\$f\"; done"
