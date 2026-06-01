#!/usr/bin/env python3
"""Fail closed on mutations while Claude Code is in plan mode."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any


MUTATING_FILE_TOOLS = {"Write", "Edit", "MultiEdit", "NotebookEdit"}
MUTATING_BASH_PATTERNS = (
    r"\bapply_patch\b",
    r"\b(?:chmod|chown|cp|install|ln|mkdir|mv|rm|rmdir|touch)\b",
    r"\b(?:docker|podman)(?:\s+compose)?\s+(?:build|down|kill|restart|rm|run|start|stop|up)\b",
    r"\bgit\s+(?:add|am|apply|checkout|cherry-pick|clean|commit|merge|mv|pull|push|rebase|reset|restore|revert|rm|stash|switch|tag)\b",
    r"\b(?:kill|killall|pkill)\b",
    r"\b(?:npm|pnpm|yarn|bun)\s+(?:add|build|ci|exec|i|install|lint|run|start|test|typecheck|verify)\b",
    r"\b(?:pip|pip3|uv\s+pip)\s+install\b",
    r"\bpytest\b",
    r"\b(?:service|systemctl)\s+(?:disable|enable|reload|restart|start|stop)\b",
    r"\bsed\s+-i\b",
    r"\btee\b",
    r"\b(?:curl|wget)\b[^\n]*(?:\s-[^\s]*[oO]|--output|--remote-name)\b",
    r"\bcurl\b[^\n]*(?:-X|--request)\s*(?:DELETE|PATCH|POST|PUT)\b",
    r"\b(?:vim|nvim|nano|emacs|code)\b",
)
MUTATING_SCRIPT_PATTERNS = (
    r"\.mkdir\s*\(",
    r"\.rename\s*\(",
    r"\.rmdir\s*\(",
    r"\.unlink\s*\(",
    r"\.write_(?:bytes|text)\s*\(",
    r"\bopen\s*\([^,\n]+,\s*[\"'][^\"']*[awx+]",
    r"\bos\.(?:makedirs|mkdir|remove|rename|replace|rmdir|unlink)\s*\(",
    r"\bshutil\.(?:copy|copy2|copyfile|copytree|move|rmtree)\s*\(",
)
OUTPUT_REDIRECT_RE = re.compile(r"(^|[\s;])(?:&>|(?:\d+)?>>?)(?!&)")


def _load_hook_input() -> dict[str, Any]:
    try:
        data = json.load(sys.stdin)
    except Exception:
        return {}
    return data if isinstance(data, dict) else {}


def _deny(reason: str) -> int:
    payload = {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
            "additionalContext": (
                "You are in a protected planning/read-only context. Present the "
                "plan with ExitPlanMode from the parent planning session and wait "
                "for explicit user approval before editing files, running "
                "verification, committing, or mutating runtime state. Read-only "
                "exploration commands are allowed."
            ),
        }
    }
    print(json.dumps(payload))
    return 0


def _is_under(path: Path, root: Path) -> bool:
    try:
        path.expanduser().resolve().relative_to(root.expanduser().resolve())
        return True
    except Exception:
        return False


def _read_latest_plan_state(transcript_path: Path) -> tuple[Path | None, bool]:
    plan_path: Path | None = None
    in_plan_mode = False

    try:
        with transcript_path.open("r", encoding="utf-8") as transcript:
            for line in transcript:
                try:
                    event = json.loads(line)
                except Exception:
                    continue

                attachment = event.get("attachment")
                if isinstance(attachment, dict):
                    attachment_type = attachment.get("type")
                    if attachment_type == "plan_mode":
                        raw_plan_path = attachment.get("planFilePath")
                        if isinstance(raw_plan_path, str) and raw_plan_path:
                            plan_path = Path(raw_plan_path).expanduser()
                        in_plan_mode = True
                    elif attachment_type == "plan_mode_exit":
                        in_plan_mode = False

                permission_mode = event.get("permissionMode")
                if permission_mode == "plan":
                    in_plan_mode = True
                elif isinstance(permission_mode, str) and permission_mode:
                    in_plan_mode = False

                if event.get("type") == "permission-mode":
                    mode = event.get("permissionMode")
                    if mode == "plan":
                        in_plan_mode = True
                    elif isinstance(mode, str) and mode:
                        in_plan_mode = False
    except Exception:
        return None, False

    return plan_path, in_plan_mode


def _message_text(message: Any) -> str:
    if isinstance(message, str):
        return message
    if not isinstance(message, dict):
        return ""
    content = message.get("content")
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts = []
        for item in content:
            if isinstance(item, str):
                parts.append(item)
            elif isinstance(item, dict) and isinstance(item.get("text"), str):
                parts.append(item["text"])
            elif isinstance(item, dict) and isinstance(item.get("content"), str):
                parts.append(item["content"])
        return "\n".join(parts)
    return ""


def _transcript_is_read_only_sidechain(transcript_path: Path) -> bool:
    try:
        with transcript_path.open("r", encoding="utf-8") as transcript:
            for index, line in enumerate(transcript):
                if index >= 40:
                    break
                try:
                    event = json.loads(line)
                except Exception:
                    continue
                if not event.get("isSidechain"):
                    continue
                if event.get("type") != "user":
                    continue

                text = _message_text(event.get("message")).lower()
                if not text:
                    continue
                read_only_signals = (
                    "read-only",
                    "do not edit",
                    "do not modify",
                    "do not commit",
                    "do not restart",
                    "no code changes",
                )
                if any(signal in text for signal in read_only_signals):
                    return True
    except Exception:
        return False
    return False


def _tool_file_path(tool_input: dict[str, Any]) -> Path | None:
    raw = tool_input.get("file_path") or tool_input.get("notebook_path")
    return Path(raw).expanduser() if isinstance(raw, str) and raw else None


def _is_allowed_plan_file(path: Path, plan_path: Path | None) -> bool:
    plans_root = Path.home() / ".claude" / "plans"
    if plan_path is not None:
        try:
            if path.resolve() == plan_path.resolve():
                return True
        except Exception:
            pass
    return path.suffix.lower() in {".md", ".markdown"} and _is_under(path, plans_root)


def _strip_heredoc_bodies(command: str) -> str:
    lines = command.splitlines()
    stripped: list[str] = []
    index = 0
    while index < len(lines):
        line = lines[index]
        stripped.append(line)
        match = re.search(r"<<-?\s*['\"]?([A-Za-z_][A-Za-z0-9_]*)['\"]?", line)
        if not match:
            index += 1
            continue

        delimiter = match.group(1)
        index += 1
        while index < len(lines) and lines[index].strip() != delimiter:
            index += 1
        if index < len(lines):
            stripped.append(delimiter)
            index += 1
    return "\n".join(stripped)


def _bash_has_mutation(command: str) -> bool:
    shell_surface = _strip_heredoc_bodies(command)
    if OUTPUT_REDIRECT_RE.search(shell_surface):
        return True
    if any(re.search(pattern, shell_surface, flags=re.IGNORECASE) for pattern in MUTATING_BASH_PATTERNS):
        return True
    return any(re.search(pattern, command, flags=re.IGNORECASE | re.DOTALL) for pattern in MUTATING_SCRIPT_PATTERNS)


def main() -> int:
    data = _load_hook_input()
    if data.get("hook_event_name") != "PreToolUse":
        return 0

    transcript_raw = data.get("transcript_path")
    if not isinstance(transcript_raw, str) or not transcript_raw:
        return 0
    transcript_path = Path(transcript_raw).expanduser()
    plan_path, in_plan_mode = _read_latest_plan_state(transcript_path)
    in_read_only_sidechain = _transcript_is_read_only_sidechain(transcript_path)
    if not in_plan_mode and not in_read_only_sidechain:
        return 0

    tool_name = data.get("tool_name")
    tool_input = data.get("tool_input")
    if not isinstance(tool_name, str) or not isinstance(tool_input, dict):
        return 0

    if tool_name in MUTATING_FILE_TOOLS:
        file_path = _tool_file_path(tool_input)
        if file_path is not None and _is_allowed_plan_file(file_path, plan_path):
            return 0
        return _deny(
            f"Plan mode blocks {tool_name} outside the active plan file. "
            "Use ExitPlanMode to present the plan before implementation."
        )

    if tool_name == "Bash":
        command = tool_input.get("command")
        if isinstance(command, str) and _bash_has_mutation(command):
            return _deny("Protected planning/read-only mode blocks mutating Bash commands.")
        return 0

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
