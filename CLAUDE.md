# Claude Code Instructions for This Repository

This repository is a public release package for the `claude-codex` launcher and supporting config.

## Public-Repo Safety

- Never commit environment files, private keys, provider auth JSON, tokens, transcripts, local sessions, logs, or machine-specific caches.
- Keep all examples credential-free. Use environment variable names such as `OPENAI_API_KEY`, never real values.
- Run `./scripts/verify-release.sh` before committing or pushing.
- Update `.gitignore` before adding any new runtime path that may contain secrets or local state.

## Scope

- Reusable user instructions live in `docs/CLAUDE-CODEX.md`.
- Release scripts live in `scripts/`.
- Launchers live in `bin/`.
- Config templates live in `config/`.
- Claude hooks live in `hooks/`.

Prefer durable, user-copyable defaults over machine-local behavior. If a local workflow depends on private services, local IP addresses, provider-specific token caches, or personal accounts, document it as an opt-in environment variable rather than making it the default.

## Verification

Before saying the repo is ready, verify:

```bash
./scripts/verify-release.sh
```

If installer behavior changed, also run:

```bash
./scripts/install.sh --dry-run
./scripts/doctor.sh
```
