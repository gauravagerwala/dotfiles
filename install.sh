#!/usr/bin/env bash
#
# install.sh — link this repo's personal config into place on a machine.
#
# What it does:
#   1. Backs up any existing files it is about to replace to
#      ~/.pi/agent/.config-backup-<timestamp>/ (per-tool dirs otherwise).
#   2. Creates symlinks from the live config locations into this repo.
#   3. Runs npm install in ~/.pi/agent/npm so pi package deps resolve.
#   4. Enables the gitleaks pre-commit hook when pre-commit is available.
#
# Safe to re-run; existing correct symlinks are left alone.
#
# New machine:
#   git clone <this-repo> ~/workspace/personal/dotfiles
#   ~/workspace/personal/dotfiles/install.sh
#   # then create ~/.config/mcp/secrets.env (see README) and run:
#   ~/.config/mcp/sync-mcp.sh --check

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PI_DIR="$HOME/.pi/agent"
CMUX_DIR="$HOME/.config/cmux"
MCP_DIR="$HOME/.config/mcp"
BACKUP_ROOT="$PI_DIR/.config-backup-$(date +%Y%m%d-%H%M%S)"

backup_created=false

link() {
  local src="$1" dst="$2"

  if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
    echo "  ok      $dst (already linked)"
    return
  fi

  if [[ -e "$dst" || -L "$dst" ]]; then
    if [[ "$backup_created" == false ]]; then
      mkdir -p "$BACKUP_ROOT"
      backup_created=true
    fi
    local backup_path="$BACKUP_ROOT/${dst#$HOME/}"
    mkdir -p "$(dirname "$backup_path")"
    mv "$dst" "$backup_path"
    echo "  backup  $dst -> $backup_path"
  fi

  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
  echo "  link    $dst -> $src"
}

echo "==> Linking pi config"
link "$REPO_DIR/pi/settings.json"                       "$PI_DIR/settings.json"
link "$REPO_DIR/pi/extensions/operation-permissions.ts" "$PI_DIR/extensions/operation-permissions.ts"
link "$REPO_DIR/pi/skills/cmux-browser"                 "$PI_DIR/skills/cmux-browser"
link "$REPO_DIR/pi/npm/package.json"                    "$PI_DIR/npm/package.json"
link "$REPO_DIR/pi/npm/package-lock.json"               "$PI_DIR/npm/package-lock.json"

echo "==> Linking cmux config"
link "$REPO_DIR/cmux/cmux.json" "$CMUX_DIR/cmux.json"

echo "==> Linking MCP sync script"
link "$REPO_DIR/mcp/sync-mcp.sh" "$MCP_DIR/sync-mcp.sh"
if [[ ! -f "$MCP_DIR/servers.json" ]]; then
  echo "  NOTE    $MCP_DIR/servers.json missing — it is per-machine and not tracked."
  echo "          Create it from $REPO_DIR/mcp/servers.example.json"
fi
if [[ ! -f "$MCP_DIR/secrets.env" ]]; then
  echo "  NOTE    $MCP_DIR/secrets.env missing — create it (chmod 600) with values"
  echo "          for the \${VAR} placeholders in your servers.json, then run:"
  echo "          sync-mcp.sh --check"
fi

echo "==> Installing pi npm package dependencies"
if command -v npm >/dev/null 2>&1; then
  (cd "$PI_DIR/npm" && npm install)
else
  echo "  npm not found; pi will install dependencies on next startup"
fi

echo "==> Enabling secret scanning"
if command -v pre-commit >/dev/null 2>&1; then
  (cd "$REPO_DIR" && pre-commit install --install-hooks)
else
  echo "  NOTE    pre-commit not found — install it, then run:"
  echo "          cd $REPO_DIR && pre-commit install --install-hooks"
fi

echo
echo "Done."
if [[ "$backup_created" == true ]]; then
  echo "Backups of replaced files are in: $BACKUP_ROOT"
fi
echo "Note: auth.json (pi credentials) and mcp/secrets.env are per-machine and intentionally not synced."
