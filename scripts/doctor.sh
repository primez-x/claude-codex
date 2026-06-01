#!/usr/bin/env bash
set -euo pipefail

BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
LITELLM_CONFIG="${CLAUDE_GATEWAY_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/litellm/claude-codex.yaml}"
CLAUDE_HOOK="${CLAUDE_HOOK:-$HOME/.claude/hooks/plan-mode-guard.py}"

ok() {
  printf 'OK: %s\n' "$1"
}

warn() {
  printf 'WARN: %s\n' "$1" >&2
}

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

check_command() {
  local name="$1"
  if command -v "$name" >/dev/null 2>&1; then
    ok "found $name"
  else
    warn "missing $name"
  fi
}

check_command claude
check_command litellm
check_command python3
check_command curl

[[ -x "$BIN_DIR/claude-codex" ]] && ok "launcher is executable: $BIN_DIR/claude-codex" || warn "launcher not found or not executable: $BIN_DIR/claude-codex"
[[ -x "$BIN_DIR/claude-litellm" ]] && ok "gateway wrapper is executable: $BIN_DIR/claude-litellm" || warn "gateway wrapper not found or not executable: $BIN_DIR/claude-litellm"
[[ -f "$LITELLM_CONFIG" ]] && ok "LiteLLM config exists: $LITELLM_CONFIG" || fail "LiteLLM config missing: $LITELLM_CONFIG"
if [[ -x "$CLAUDE_HOOK" ]]; then
  ok "plan-mode guard is executable: $CLAUDE_HOOK"
  HOOK_PATH="$CLAUDE_HOOK" python3 -B <<'PY'
import os
from pathlib import Path

path = Path(os.environ["HOOK_PATH"])
compile(path.read_text(), str(path), "exec")
PY
  ok "plan-mode guard syntax is valid"
else
  warn "plan-mode guard missing or not executable: $CLAUDE_HOOK"
fi

CONFIG="$LITELLM_CONFIG" python3 <<'PY'
import os
import sys
from pathlib import Path

try:
    import yaml
except Exception as exc:
    print(f"WARN: PyYAML unavailable, skipping YAML parse: {exc}", file=sys.stderr)
    raise SystemExit(0)

path = Path(os.environ["CONFIG"])
data = yaml.safe_load(path.read_text())
if not isinstance(data, dict):
    raise SystemExit("FAIL: LiteLLM config must parse to an object")
models = data.get("model_list")
if not isinstance(models, list) or not models:
    raise SystemExit("FAIL: LiteLLM config has no model_list")
names = [item.get("model_name") for item in models if isinstance(item, dict)]
print(f"OK: parsed {len(names)} model aliases")
PY

if [[ -n "${OPENAI_API_KEY:-}" ]]; then
  ok "OPENAI_API_KEY is set"
else
  warn "OPENAI_API_KEY is not set; direct OpenAI-compatible routes may fail"
fi

if [[ -f "${CHATGPT_TOKEN_DIR:-$HOME/.config/litellm/chatgpt}/${CHATGPT_AUTH_FILE:-auth.json}" ]]; then
  ok "LiteLLM ChatGPT auth file exists"
else
  warn "LiteLLM ChatGPT auth file not found; chatgpt/... routes may require login or CLAUDE_CODEX_SYNC_CODEX_AUTH=1"
fi

printf '\nDoctor checks finished.\n'
