# Security Policy

This is a public repository. Treat every committed file as public forever.

## Do Not Commit

- `.env` files or shell exports containing real values.
- `~/.codex/auth.json`.
- `~/.config/litellm/chatgpt/auth.json`.
- `~/.claude.json`.
- Claude or Codex transcripts and session JSONL files.
- API keys, OAuth tokens, private keys, SSH keys, certificates, cookies, or provider account IDs.
- Logs that may contain prompts, responses, request headers, bearer tokens, or local file paths from private projects.

## Safe Pattern

Use environment variable references in examples:

```yaml
api_key: os.environ/OPENAI_API_KEY
```

Use placeholders in documentation:

```bash
export OPENAI_API_KEY="your-api-key"
```

## Before Publishing

Run:

```bash
./scripts/verify-release.sh
git status --short
```

Review the full diff before pushing.

## Reporting

If a secret is accidentally committed, rotate the credential immediately. Removing it in a later commit is not enough because the value remains in Git history.
