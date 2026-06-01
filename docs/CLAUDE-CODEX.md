# Claude-Codex Project Instructions

Copy this file into a project as `CLAUDE.md`, or reference it from an existing `CLAUDE.md`, when using the `claude-codex` launcher.

## Default Engineering Standard: Best-In-Class First

When proposing solutions, recommendations, architecture, enhancements, refactors, or implementation plans, default to the highest-quality, most robust option.

Do not optimize primarily for speed, ease, minimal effort, short-term convenience, or low cost unless explicitly asked. Hard safety blocks, security requirements, and explicit user constraints remain absolute.

Prefer solutions that maximize, in order:

1. Correctness and reliability
2. Long-term maintainability
3. Security and safety
4. Performance and scalability
5. Observability, debuggability, and operability
6. Clean architecture and strong abstractions
7. User experience and polish
8. Testability and documentation
9. Ease of implementation

If several approaches exist, present the best overall solution first. Clearly label cheaper, faster, or simpler alternatives as compromises.

## Think Before Coding

Before implementing:

- State assumptions explicitly when they affect correctness, safety, architecture, or scope.
- If multiple interpretations exist, present them instead of picking silently.
- Check for existing helpers before adding new functions or scripts.
- Prefer one well-owned implementation over duplicate logic.
- Push back when the requested path creates avoidable risk, duplication, or long-term maintenance cost.

## Simplicity Without Under-Engineering

Build the cleanest complete solution. Avoid unrelated features and speculative abstractions, but do not use simplicity as a reason to lower the quality bar.

- No features beyond what was asked unless required for correctness, safety, operability, or maintainability.
- No abstractions for single-use code unless they materially reduce risk or clarify an important boundary.
- Handle realistic edge cases and failure modes thoroughly.
- If a smaller implementation has the same correctness, robustness, and clarity, prefer it.

## Planning And Approval

In planning mode:

- Present the plan clearly before implementation.
- Do not edit files outside the active plan document.
- Do not commit, push, restart services, run mutating scripts, or perform runtime mutations.
- Wait for explicit user approval before implementation.

In implementation mode:

- Keep changes scoped to the requested work.
- Read files before editing them.
- Do not revert user changes unless explicitly asked.
- Stage only files that belong to the completed task.

## Verification Before Completion

A task is not complete until relevant verification has been run and read.

Consider:

- Automated tests or a clear reason tests are not practical.
- Type checks, linting, formatting, or equivalent verification.
- Edge cases and failure modes.
- Security implications.
- Performance implications.
- Backward compatibility or migration concerns.
- Documentation or comments where useful.
- Operational visibility when relevant.

Report what was verified and what was not.

## Security Rules

- Never hardcode API keys, secrets, credentials, tokens, cookies, or private key material.
- Never commit `.env` files or provider auth JSON.
- Use environment variables for credentials.
- Sanitize logs and command output before sharing.
- Validate user input at system boundaries.
- Sanitize file paths where untrusted input can affect filesystem access.

## Claude-Codex Gateway Notes

- Default launcher: `claude-codex`.
- Gateway config: `~/.config/litellm/claude-codex.yaml`.
- Main wrapper: `claude-litellm`.
- Plan-mode safety hook: `~/.claude/hooks/plan-mode-guard.py`.
- Codex CLI defaults: `~/.codex/config.toml`.

Keep provider credentials outside project files. Prefer `api_key: os.environ/OPENAI_API_KEY` in LiteLLM config examples.

## Useful Commands

```bash
claude-codex
CLAUDE_GATEWAY_MODEL=gpt-5.3-codex claude-codex
CLAUDE_GATEWAY_PORT=4017 claude-codex
CLAUDE_CODEX_SYNC_CODEX_AUTH=1 claude-codex
```

Only enable `CLAUDE_GATEWAY_DANGEROUSLY_SKIP_PERMISSIONS=1` when you intentionally want Claude Code to bypass its normal permission prompts.
