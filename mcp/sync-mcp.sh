#!/usr/bin/env bash
#
# sync-mcp.sh — sync canonical MCP server config to all AI tools.
#
# Source of truth: ~/.config/mcp/servers.json (machine-local and never committed).
# Secrets are NOT stored in that file; it contains ${VAR} placeholders
# expanded at sync time from:
#   1. the process environment, or
#   2. ~/.config/mcp/secrets.env (per-machine, chmod 600, never committed)
#
# Usage:
#   sync-mcp.sh           sync all targets
#   sync-mcp.sh --check   verify all placeholders can be expanded, write nothing
#
set -euo pipefail

# Any newly created config can contain expanded credentials.
umask 077

CANONICAL="$HOME/.config/mcp/servers.json"
SECRETS_FILE="$HOME/.config/mcp/secrets.env"
CHECK_ONLY=false
[[ "${1:-}" == "--check" ]] && CHECK_ONLY=true

if [[ ! -f "$CANONICAL" ]]; then
  echo "Error: $CANONICAL not found"
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "Error: jq is required but not installed"
  exit 1
fi

if [[ -f "$SECRETS_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$SECRETS_FILE"
  set +a
fi

# Expand ${VAR} placeholders found in the canonical file.
PLACEHOLDERS=$(grep -oE '\$\{[A-Z0-9_]+\}' "$CANONICAL" | sort -u | sed 's/^\${//; s/}$//' || true)

jq_args=()
missing=()
for v in $PLACEHOLDERS; do
  if [[ -z "${!v:-}" ]]; then
    missing+=("$v")
  else
    jq_args+=(--arg "$v" "${!v}")
  fi
done

if ((${#missing[@]})); then
  echo "Error: missing secret values for: ${missing[*]}" >&2
  echo "Set them in your environment or in $SECRETS_FILE" >&2
  exit 1
fi

EXPAND='
  reduce ($ARGS.named | to_entries[]) as $e (.;
    (.. | strings) |= gsub("\\$\\{" + $e.key + "\\}"; $e.value))
  | if [.. | strings | select(test("\\$\\{[A-Z0-9_]+\\}"))] | length > 0
    then error("unexpanded placeholder remains") else . end
'

if ((${#jq_args[@]})); then
  SERVERS=$(jq "${jq_args[@]}" "$EXPAND" "$CANONICAL" | jq '.servers')
else
  SERVERS=$(jq '.servers' "$CANONICAL")
fi

if [[ "$CHECK_ONLY" == true ]]; then
  echo "OK: all placeholders expandable (${PLACEHOLDERS//$'\n'/, })"
  echo "Servers: $(echo "$SERVERS" | jq -r 'keys | join(", ")')"
  exit 0
fi

sync_claude_code() {
  local target="$HOME/.claude/settings.json"
  mkdir -p "$(dirname "$target")"
  if [[ -f "$target" ]]; then
    local merged
    merged=$(jq --argjson servers "$SERVERS" '.mcpServers = $servers' "$target")
    echo "$merged" | jq '.' > "$target"
  else
    jq -n --argjson servers "$SERVERS" '{ mcpServers: $servers }' > "$target"
  fi
  chmod 600 "$target"
  echo "Synced: $target (mcpServers)"
}

sync_copilot() {
  local target="$HOME/.copilot/mcp-config.json"
  mkdir -p "$(dirname "$target")"
  if [[ -f "$target" ]]; then
    local merged
    merged=$(jq --argjson servers "$SERVERS" '.mcpServers = $servers' "$target")
    echo "$merged" | jq '.' > "$target"
  else
    jq -n --argjson servers "$SERVERS" '{ mcpServers: $servers }' > "$target"
  fi
  chmod 600 "$target"
  echo "Synced: $target (mcpServers)"
}

sync_vscode() {
  local target="$HOME/Library/Application Support/Code/User/mcp.json"
  mkdir -p "$(dirname "$target")"
  if [[ -f "$target" ]]; then
    local merged
    merged=$(jq --argjson servers "$SERVERS" '.servers = $servers' "$target")
    echo "$merged" | jq '.' > "$target"
  else
    jq -n --argjson servers "$SERVERS" '{ servers: $servers }' > "$target"
  fi
  chmod 600 "$target"
  echo "Synced: $target (servers)"
}

sync_opencode() {
  local target="$HOME/.config/opencode/opencode.json"
  mkdir -p "$(dirname "$target")"
  local oc_servers
  oc_servers=$(echo "$SERVERS" | jq 'with_entries(
    if .value.type == "http" then
      .value.type = "remote"
    elif .value.type == "stdio" then
      .value = {
        type: "local",
        command: ([.value.command] + .value.args),
        environment: (.value.env // {})
      }
    else . end
  )')
  if [[ -f "$target" ]]; then
    local merged
    merged=$(jq --argjson servers "$oc_servers" '.mcp = $servers' "$target")
    echo "$merged" | jq '.' > "$target"
  else
    jq -n --argjson servers "$oc_servers" '{ "$schema": "https://opencode.ai/config.json", mcp: $servers }' > "$target"
  fi
  chmod 600 "$target"
  echo "Synced: $target (mcp)"
}

sync_pi() {
  # Preferred shared global config for pi-mcp-adapter
  local target="$HOME/.config/mcp/mcp.json"
  mkdir -p "$(dirname "$target")"
  jq -n --argjson servers "$SERVERS" '{ mcpServers: $servers }' > "$target"
  chmod 600 "$target"
  echo "Synced: $target (mcpServers)"
}

echo "Reading canonical config: $CANONICAL"
echo "Servers found: $(echo "$SERVERS" | jq -r 'keys | join(", ")')"
echo ""

sync_claude_code
sync_copilot
sync_vscode
sync_opencode
sync_pi

echo ""
echo "All configs synced."
