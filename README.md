# dotfiles

Personal configuration for my dev tools, shared across machines via symlinks.
Currently covers **pi**, **cmux**, shared **agent skills** for AI tools
(Codex, opencode, Claude Code, Copilot CLI, VS Code, pi), and a **generic MCP config
sync script**.

Deliberately generic: no employer-specific hosts, paths, credentials, or
project references are tracked in this repo.

## Layout

```
pi/
  settings.json                -> ~/.pi/agent/settings.json
  extensions/
    operation-permissions.ts   -> ~/.pi/agent/extensions/operation-permissions.ts
  npm/
    package.json               -> ~/.pi/agent/npm/package.json
    package-lock.json          -> ~/.pi/agent/npm/package-lock.json
skills/
  cmux-browser/                -> every tool (see Skills below)
  deslop/
  test-audit/
  technical-documentation/
  respond-for-understanding/
  learning-retro/
codex/
  AGENTS.md                      (understanding routing fragment)
  understanding.sh               (sourced by install.sh)
  understanding-memory.template.md (empty template; live memory stays local)
  evals/scenarios.md             (behavioral evaluation prompts)
cmux/
  cmux.json                    -> ~/.config/cmux/cmux.json
mcp/
  sync-mcp.sh                  -> ~/.config/mcp/sync-mcp.sh
  servers.example.json           (template only — your real servers.json stays local)
.pre-commit-config.yaml          (gitleaks secret scanning)
install.sh
```

## New machine setup

```sh
git clone <remote-url> ~/workspace/personal/dotfiles
~/workspace/personal/dotfiles/install.sh
```

Then the per-machine pieces (never committed):

1. **pi login** — `pi` will prompt on first run (`~/.pi/agent/auth.json`).
2. **MCP servers** — create `~/.config/mcp/servers.json` from
   `mcp/servers.example.json` with your own servers, using `${VAR}`
   placeholders for any credentials.
3. **MCP secrets** — create `~/.config/mcp/secrets.env` (chmod 600) defining
   each `${VAR}` used in your `servers.json`.
4. Verify with `~/.config/mcp/sync-mcp.sh --check`, then run it to sync.
5. Install [pre-commit](https://pre-commit.com/) if needed, then enable the
   repository's secret scanner with `pre-commit install --install-hooks`.
   `install.sh` does this automatically when `pre-commit` is available.

## Skills

`skills/` holds tool-agnostic agent skills. `install.sh` symlinks every
directory in it into each tool's skills location, so one edit here is one edit
everywhere.

| Tool | Skills directory |
|------|------------------|
| Codex, opencode, Copilot CLI, VS Code Copilot | `~/.agents/skills/` |
| Claude Code | `~/.claude/skills/` |
| Copilot CLI (older builds) | `~/.copilot/skills/` |
| pi | `~/.pi/agent/skills/` |

Add a skill by creating `skills/<name>/SKILL.md` with `name` and `description`
frontmatter and re-running `install.sh`; nothing else needs editing. A skill
directory already present in a target is moved to the timestamped backup before
being replaced, so local edits are never silently lost.

Current skills:

- `cmux-browser` — browser automation through the cmux CLI.
- `deslop` — diff-scoped cleanup of AI-slop comments, defensive checks, and
  type-laundering before code review.
- `test-audit` — authoring gate and audit workflow for test value, junk
  patterns, and test-only production seams.
- `technical-documentation` — build and review of technical docs and agent
  instruction files (`AGENTS.md` / `CONTRIBUTING.md`).
- `respond-for-understanding` — adapt substantive coding answers to evidence
  of the user's understanding, avoiding repeated background.
- `learning-retro` — review session evidence and update a brief understanding
  memory when requested.

## Codex understanding workflow

The existing `install.sh` installs both learning skills through the shared
symlink loop. It also merges the marked `codex/AGENTS.md` routing fragment into
`~/.codex/AGENTS.md` and initializes an empty local memory at
`~/.codex/understanding/default/memory.md`. When `CODEX_HOME` is configured,
both paths use that directory instead. A nonempty `AGENTS.override.md` receives
the routing block in place of `AGENTS.md`.

Existing instructions outside the marked block, existing symlinks, and personal
memory are preserved on reinstallation. Setup creates memory as a mutable local
file outside the shared skill source. The tracked template contains no user knowledge.
The default profile assumes a single user; shared sessions must explicitly
select their own profile and memory. Relative memory paths resolve from the
applicable routing file's directory, not from a project's current directory.

Ask normal coding questions. The response skill description supports discovery;
the routing rule requests its use before substantive answers. After a useful
session, request `$learning-retro Review this session and update my understanding
memory.` Explicitly request a retro or correction to write memory; routine
answers only read it. You can request a read-only proposal or ask the retro to
correct or forget an entry.

The flat file distinguishes exposure, self-reported understanding, demonstrated
understanding, and specific gaps. An explanation delivered or accepted generated
code never establishes demonstrated understanding. Current instructions and
evidence override saved claims. Retros keep the whole file within 600 words,
15 concepts, and 5 preference bullets. One writer at a time is supported.
See the [memory contract](skills/respond-for-understanding/references/memory-contract.md)
and [behavioral evaluation scenarios](codex/evals/scenarios.md).

The skills are Markdown instructions and need no Python at runtime. The Bash
setup uses standard `awk`, `cmp`, and `mktemp`. Run setup-preservation checks
with `python3 -m unittest discover -s codex/tests -v` and syntax checks with
`bash -n install.sh codex/understanding.sh`. These checks do not establish
model invocation or learning effectiveness; the scenarios cover those separately.

Matt Pocock's [retro](https://github.com/mattpocock/skills/releases) motivated the
session-review loop. This implementation adds scoped understanding evidence and
does not depend on that skill. Codex guidance requests behavior; it is not a
guaranteed response hook. See [Codex skills](https://developers.openai.com/codex/skills).

## MCP sync

`sync-mcp.sh` reads the canonical server list from
`~/.config/mcp/servers.json` (per-machine, gitignored) and rewrites each
tool's config. `${VAR}` placeholders are expanded from the environment or
`secrets.env`; sync fails if any placeholder is missing.

| Tool | Target |
|------|--------|
| Claude Code | `~/.claude/settings.json` (`mcpServers`) |
| Copilot CLI | `~/.copilot/mcp-config.json` (`mcpServers`) |
| VS Code | `~/Library/Application Support/Code/User/mcp.json` (`servers`) |
| opencode | `~/.config/opencode/opencode.json` (`mcp`, schema-translated) |
| pi | `~/.config/mcp/mcp.json` (generated, gitignored) |

Targets are tool-specific generated files — edit `servers.json`, re-run
`sync-mcp.sh`; never edit targets directly. Because generated targets can
contain expanded credentials, the sync script creates them with restrictive
permissions and enforces mode `600` on every target.

## Secret scanning

The pre-commit configuration runs gitleaks against staged changes. To scan the
whole tracked tree at any time:

```sh
pre-commit run gitleaks --all-files
```

The ignore rules cover common credential files as defense in depth, but files
must still use placeholders such as `${TOKEN}` rather than real secret values.

## Day-to-day

- Edit files here (or edit live files — they symlink here) and commit.
  `git status` shows config drift.
- pi occasionally rewrites `settings.json` (`lastChangelogVersion`);
  committing those diffs is harmless.
- Add a pi package: `pi install <pkg>` updates `settings.json` and
  `npm/package.json` — commit both.

## Deliberately NOT synced

| Path | Why |
|------|-----|
| `~/.config/mcp/servers.json` | Machine/work-specific MCP servers |
| `~/.config/mcp/secrets.env` | MCP credentials — per-machine secret |
| `~/.config/mcp/mcp.json` | Generated by sync-mcp.sh (contains secrets) |
| `~/.pi/agent/auth.json` | OAuth credentials — per-machine secret |
| `~/.pi/agent/trust.json` | Machine-specific trusted project paths |
| `~/.pi/agent/sessions/` | Session transcripts |
| `~/.pi/agent/bin/` | Downloaded binaries (fd, rg) |
| `~/.pi/agent/models-store.json` | Auto-refreshed model catalog cache |
| `~/.pi/agent/mcp-*.json` | MCP caches/onboarding state |
| `~/.pi/agent/npm/node_modules/` | Reinstalled from package-lock |
| `~/.codex/understanding/` (or `$CODEX_HOME/understanding/`) | Personal understanding memory |
| `~/Library/Application Support/cmux/` | cmux runtime state (sessions, search DB) |

## cmux notes

cmux reads `~/.config/cmux/cmux.json` (JSONC) on launch; any key set there is
file-managed and overrides the in-app Settings value. The tracked file is
currently the default template with everything commented out — uncomment and
edit keys to make them portable. Settings left commented live in macOS user
defaults (window frames, notification history, etc.), which are machine-local
and not synced.
