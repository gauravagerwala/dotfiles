#!/usr/bin/env bash
# Sourced by install.sh; add routing while keeping understanding memory local.

setup_understanding() (
  set -euo pipefail
  local source_dir="$1" codex_dir="$2"
  local memory_file="$codex_dir/understanding/default/memory.md"
  local agents_file="$codex_dir/AGENTS.md" existing_agents staged

  if [[ ! -f "$source_dir/AGENTS.md" || ! -f "$source_dir/understanding-memory.template.md" ]]; then
    echo "Understanding setup: routing fragment or memory template is missing." >&2
    return 1
  fi

  # A profile or format mismatch must not overwrite existing personal memory.
  if [[ -e "$memory_file" || -L "$memory_file" ]]; then
    if ! awk '
      /^Format: / { formats++; if ($0 != "Format: understanding-memory-v1") invalid = 1 }
      /^Profile: / { profiles++; if ($0 != "Profile: default") invalid = 1 }
      END { exit (invalid || formats != 1 || profiles != 1) }
    ' "$memory_file"; then
      echo "Understanding setup: incompatible memory at $memory_file; preserved." >&2
      return 1
    fi
  fi

  mkdir -p "$codex_dir"
  if [[ -s "$codex_dir/AGENTS.override.md" ]]; then
    agents_file="$codex_dir/AGENTS.override.md"
  fi
  existing_agents=/dev/null
  if [[ -e "$agents_file" || -L "$agents_file" ]]; then
    existing_agents="$agents_file"
  fi
  staged="$(mktemp "$codex_dir/.understanding-routing.XXXXXX")"
  trap 'rm -f "$staged"' EXIT

  # Replace only our marked block. Reject damaged markers before creating
  # memory or changing user instructions. Preserve all other sections.
  if ! awk '
    BEGIN {
      start = "<!-- understanding-workflow:start -->"
      finish = "<!-- understanding-workflow:end -->"
    }
    NR == FNR { fragment = fragment $0 ORS; next }
    {
      lines++
      if ($0 == start) {
        if (inside || seen) invalid = 1
        inside = 1; seen = 1
        printf "%s", fragment
        next
      }
      if ($0 == finish) {
        if (!inside) invalid = 1
        inside = 0; closed++
        next
      }
      if (!inside) print
    }
    END {
      if (inside || invalid || (seen && closed != 1)) exit 1
      if (!seen) {
        if (lines) print ""
        printf "%s", fragment
      }
    }
  ' "$source_dir/AGENTS.md" "$existing_agents" > "$staged"; then
    echo "Understanding setup: repair the routing markers in $agents_file; preserved." >&2
    return 1
  fi

  if [[ ! -e "$memory_file" && ! -L "$memory_file" ]]; then
    mkdir -p "$(dirname "$memory_file")"
    # Noclobber prevents a concurrent creation from replacing personal data.
    (
      umask 077
      set -C
      awk -v today="$(date -u +%Y-%m-%d)" '
        /^Updated: never$/ { print "Updated: " today; next }
        { print }
      ' "$source_dir/understanding-memory.template.md" > "$memory_file"
    )
    echo "  create  $memory_file (empty understanding memory)"
  else
    echo "  keep    $memory_file (personal memory preserved)"
  fi

  if cmp -s "$staged" "$existing_agents"; then
    echo "  ok      $agents_file (routing already configured)"
  else
    # Writing through an existing symlink preserves its ownership convention.
    # Existing file permissions are retained; a new file is owner-readable only.
    if [[ -e "$agents_file" || -L "$agents_file" ]]; then
      cat "$staged" > "$agents_file"
    else
      (umask 077; set -C; cat "$staged" > "$agents_file")
    fi
    echo "  update  $agents_file (understanding routing)"
  fi
)
