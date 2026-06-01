#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

bash -n bin/claude-codex
bash -n bin/claude-litellm
bash -n scripts/install.sh
bash -n scripts/doctor.sh
bash -n scripts/verify-release.sh

python3 -B <<'PY'
from pathlib import Path

path = Path("hooks/plan-mode-guard.py")
compile(path.read_text(), str(path), "exec")
print("plan-mode guard syntax parsed")
PY

python3 <<'PY'
import json
from pathlib import Path

json.loads(Path("config/claude/settings.hooks.example.json").read_text())
print("JSON config example parsed")
PY

python3 <<'PY'
from pathlib import Path

try:
    import yaml
except Exception as exc:
    raise SystemExit(f"PyYAML is required for release verification: {exc}")

data = yaml.safe_load(Path("config/litellm/claude-codex.yaml").read_text())
if not isinstance(data, dict):
    raise SystemExit("LiteLLM YAML must parse to a mapping")
models = data.get("model_list")
if not isinstance(models, list) or not models:
    raise SystemExit("LiteLLM YAML must contain a non-empty model_list")
names = [model.get("model_name") for model in models if isinstance(model, dict)]
if len(names) != len(set(names)):
    raise SystemExit("LiteLLM YAML contains duplicate model_name entries")
for model in models:
    if not isinstance(model, dict):
        raise SystemExit("Every model_list item must be a mapping")
    if "model_name" not in model or "litellm_params" not in model:
        raise SystemExit(f"Invalid model entry: {model!r}")
print(f"LiteLLM YAML parsed with {len(names)} model aliases")
PY

if rg --pcre2 -n \
  '(sk-[A-Za-z0-9_-]{20,}|ghp_[A-Za-z0-9_]{20,}|gho_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|xox[baprs]-[A-Za-z0-9-]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----)' \
  --glob '!*.bak' \
  .; then
  printf 'Potential secret-like value found. Review output above.\n' >&2
  exit 1
fi

if find . -path ./.git -prune -o \( -name '.env' -o -name '*.pem' -o -name '*.key' -o -name 'auth.json' -o -name '*.jsonl' \) -print | rg .; then
  printf 'Sensitive runtime file pattern found in working tree.\n' >&2
  exit 1
fi

git diff --check

printf 'Release verification passed.\n'
