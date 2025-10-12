# Add this to your ~/.bashrc.d/kind-plugins.sh (or source it in your shell)

kind-plugin() {
  local KIND_PLUGIN_DIR="${KIND_PLUGIN_DIR:-$HOME/.kind/plugin}"

  show_help() {
    echo "Usage: kind-plugin <plugin> [command] [args...]"
    echo
    echo "Available plugins:"
    if [[ -d "$KIND_PLUGIN_DIR" ]]; then
      # list *.sh under ~/.kind/plugin
      local found=0
      while IFS= read -r p; do
        found=1
        echo "  - $(basename "$p" .sh)"
      done < <(find "$KIND_PLUGIN_DIR" -maxdepth 1 -type f -name "*.sh" | sort)
      [[ $found -eq 0 ]] && echo "  (no plugins found in $KIND_PLUGIN_DIR)"
    else
      echo "  (no plugins dir: $KIND_PLUGIN_DIR)"
    fi
    echo
    echo "Examples:"
    echo "  kind-plugin epinio install"
    echo "  kind-plugin olm status"
  }

  # No plugin or help -> show help
  local plugin="${1:-}"
  if [[ -z "$plugin" || "$plugin" == "--help" || "$plugin" == "-h" ]]; then
    show_help
    return 0
  fi

  # Resolve plugin path
  local plugin_path="$KIND_PLUGIN_DIR/${plugin}.sh"
  if [[ ! -f "$plugin_path" ]]; then
    echo "❌ Plugin not found: $plugin"
    echo "👉 Expected at: $plugin_path"
    return 1
  fi

  # Ensure executable (don’t fail if chmod not allowed)
  chmod +x "$plugin_path" 2>/dev/null || true

  # Run plugin with remaining args (default to 'help' if no subcommand provided)
  if [[ $# -eq 1 ]]; then
    "$plugin_path" help
  else
    "$plugin_path" "${@:2}"
  fi
}
