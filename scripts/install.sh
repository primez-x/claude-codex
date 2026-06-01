#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PREFIX="${PREFIX:-$HOME/.local}"
BIN_DIR="${BIN_DIR:-$PREFIX/bin}"
LITELLM_CONFIG_DIR="${LITELLM_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/litellm}"
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
CODEX_DIR="${CODEX_DIR:-$HOME/.codex}"
FORCE=0
DRY_RUN=0
INSTALL_HOOK=1

usage() {
  cat <<'EOF'
Usage: scripts/install.sh [options]

Options:
  --force          Overwrite existing launcher/config files.
  --dry-run        Print actions without changing files.
  --no-hook        Do not install or register the Claude PreToolUse hook.
  -h, --help       Show this help.

Environment overrides:
  PREFIX                 Default: $HOME/.local
  BIN_DIR                Default: $PREFIX/bin
  LITELLM_CONFIG_DIR     Default: $XDG_CONFIG_HOME/litellm or ~/.config/litellm
  CLAUDE_DIR             Default: ~/.claude
  CODEX_DIR              Default: ~/.codex
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force)
      FORCE=1
      ;;
    --dry-run)
      DRY_RUN=1
      ;;
    --no-hook)
      INSTALL_HOOK=0
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

run() {
  if [[ "$DRY_RUN" == "1" ]]; then
    printf 'DRY RUN:'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

install_file() {
  local src="$1"
  local dest="$2"
  local mode="$3"

  if [[ -e "$dest" && "$FORCE" != "1" ]]; then
    printf 'Keeping existing %s. Use --force to overwrite.\n' "$dest"
    return 0
  fi

  run install -D -m "$mode" "$src" "$dest"
}

install_file "$REPO_ROOT/bin/claude-codex" "$BIN_DIR/claude-codex" 0755
install_file "$REPO_ROOT/bin/claude-litellm" "$BIN_DIR/claude-litellm" 0755
install_file "$REPO_ROOT/config/litellm/claude-codex.yaml" "$LITELLM_CONFIG_DIR/claude-codex.yaml" 0644

if [[ ! -e "$CODEX_DIR/config.toml" ]]; then
  install_file "$REPO_ROOT/config/codex/config.example.toml" "$CODEX_DIR/config.toml" 0644
else
  printf 'Keeping existing %s. Merge config/codex/config.example.toml manually if needed.\n' "$CODEX_DIR/config.toml"
fi

if [[ "$INSTALL_HOOK" == "1" ]]; then
  hook_path="$CLAUDE_DIR/hooks/plan-mode-guard.py"
  settings_path="$CLAUDE_DIR/settings.json"
  install_file "$REPO_ROOT/hooks/plan-mode-guard.py" "$hook_path" 0755

  if [[ "$DRY_RUN" == "1" ]]; then
    printf 'DRY RUN: register PreToolUse hook %s in %s\n' "$hook_path" "$settings_path"
  else
    CLAUDE_SETTINGS_PATH="$settings_path" CLAUDE_HOOK_PATH="$hook_path" python3 <<'PY'
import json
import os
import shutil
import time
from pathlib import Path

settings_path = Path(os.environ["CLAUDE_SETTINGS_PATH"]).expanduser()
hook_path = str(Path(os.environ["CLAUDE_HOOK_PATH"]).expanduser())
settings_path.parent.mkdir(parents=True, exist_ok=True)

if settings_path.exists():
    backup = settings_path.with_suffix(settings_path.suffix + f".bak.{int(time.time())}")
    shutil.copy2(settings_path, backup)
    try:
        data = json.loads(settings_path.read_text())
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Cannot parse {settings_path}: {exc}")
else:
    data = {}

if not isinstance(data, dict):
    raise SystemExit(f"{settings_path} must contain a JSON object")

hooks = data.setdefault("hooks", {})
if not isinstance(hooks, dict):
    raise SystemExit(f"{settings_path}: hooks must be a JSON object")

pre_tool = hooks.setdefault("PreToolUse", [])
if not isinstance(pre_tool, list):
    raise SystemExit(f"{settings_path}: hooks.PreToolUse must be a JSON array")

entry = {
    "matcher": "",
    "hooks": [
        {
            "type": "command",
            "command": hook_path,
        }
    ],
}

def has_hook(item):
    if not isinstance(item, dict):
        return False
    for hook in item.get("hooks", []):
        if isinstance(hook, dict) and hook.get("command") == hook_path:
            return True
    return False

if not any(has_hook(item) for item in pre_tool):
    pre_tool.insert(0, entry)

settings_path.write_text(json.dumps(data, indent=2) + "\n")
settings_path.chmod(0o600)
PY
  fi
fi

printf '\nInstalled claude-codex files.\n'
printf 'Add %s to PATH if needed.\n' "$BIN_DIR"
printf 'Run scripts/doctor.sh from this repo to validate the installation.\n'
