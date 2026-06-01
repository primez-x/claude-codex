# claude-codex

`claude-codex` is a public, copyable setup for running Claude Code against a local LiteLLM gateway with Codex-oriented model aliases, safer plan-mode guardrails, and reusable project instructions.

This repo intentionally ships templates and scripts only. It does not include environment files, provider auth files, private keys, transcripts, tokens, or machine-local caches.

## What Is Included

- `bin/claude-codex` - Claude Code launcher with Codex defaults and model discovery enabled.
- `bin/claude-litellm` - LiteLLM gateway bootstrapper used by the launcher.
- `config/litellm/claude-codex.yaml` - sanitized LiteLLM model aliases.
- `hooks/plan-mode-guard.py` - Claude Code `PreToolUse` hook that blocks edits, commits, test runs, restarts, and other mutations while Claude is still in planning or read-only context.
- `docs/CLAUDE-CODEX.md` - reusable Claude Code project instructions adapted for this gateway.
- `config/codex/config.example.toml` - Codex CLI defaults to merge into `~/.codex/config.toml`.
- `config/claude/settings.hooks.example.json` - hook registration example.
- `scripts/install.sh` - idempotent local installer.
- `scripts/doctor.sh` - local installation checks.
- `scripts/verify-release.sh` - maintainer verification before publishing.

## Requirements

- Claude Code CLI available as `claude`.
- LiteLLM CLI available as `litellm`.
- Python 3.
- `curl`.
- One provider auth path:
  - `OPENAI_API_KEY` for direct OpenAI-compatible routes in the YAML, or
  - LiteLLM ChatGPT provider auth for `chatgpt/...` routes.

Install LiteLLM in the Python environment you use for command-line tools:

```bash
python3 -m pip install litellm
```

## Quick Start

```bash
git clone https://github.com/primez-x/claude-codex.git
cd claude-codex
./scripts/verify-release.sh
./scripts/install.sh
export OPENAI_API_KEY="your-api-key"
claude-codex
```

The installer copies launchers into `~/.local/bin`, installs the LiteLLM config into `~/.config/litellm/claude-codex.yaml`, installs the plan-mode guard into `~/.claude/hooks`, and registers the hook in `~/.claude/settings.json`.

Make sure `~/.local/bin` is on your `PATH`.

## Auth Notes

Never put real credentials in this repository.

Direct model routes use:

```yaml
api_key: os.environ/OPENAI_API_KEY
```

ChatGPT-provider routes use LiteLLM's local auth store. If you want the launcher to copy a local Codex auth token into LiteLLM's ChatGPT auth location on your own machine, opt in explicitly:

```bash
export CLAUDE_CODEX_SYNC_CODEX_AUTH=1
claude-codex
```

That token copy stays under your home directory, normally `~/.config/litellm/chatgpt/auth.json`, and is ignored by this repo.

## Model Aliases

The bundled YAML mirrors the Codex-focused alias shape from the local setup:

- `opusplan`
- `opusplan-opus-4-8[1m]`
- `gpt-5.5`
- `gpt-5.5-codex`
- `gpt-5.4`
- `gpt-5.4-mini`
- `gpt-5.3-codex-spark`
- `gpt-5.3-codex`
- `gpt-5.2-codex`
- `gpt-5.1-codex`
- `gpt-5.1-codex-max`
- `gpt-5.1-codex-mini`
- `gpt-5-codex`

Edit `config/litellm/claude-codex.yaml` after install if your provider account exposes different model names or context windows.

## Project Instructions

Use [docs/CLAUDE-CODEX.md](docs/CLAUDE-CODEX.md) as the reusable instruction profile for projects that run through this launcher.

Recommended options:

- Copy it into a project as `CLAUDE.md`.
- Keep your existing `CLAUDE.md` and add a short reference asking Claude to read `CLAUDE-CODEX.md` before work.
- Keep project-specific build/test commands in your local `CLAUDE.md`; do not put secrets there.

## Safety Defaults

- Permission bypass is off by default. Set `CLAUDE_GATEWAY_DANGEROUSLY_SKIP_PERMISSIONS=1` only if you understand the risk.
- The LiteLLM gateway binds to `127.0.0.1` by default.
- Plan mode is guarded by a `PreToolUse` hook that fails closed for mutations.
- `.gitignore` excludes auth files, env files, transcripts, key material, token caches, logs, and common runtime state.

## Verification

Run this before publishing changes:

```bash
./scripts/verify-release.sh
```

Run this after installing on a user machine:

```bash
./scripts/doctor.sh
```

## Security

See [SECURITY.md](SECURITY.md). Do not open issues or pull requests containing credentials, token values, private logs, or full auth JSON files.

## License

MIT. See [LICENSE](LICENSE).
