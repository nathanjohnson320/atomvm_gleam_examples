#!/usr/bin/env python3
"""Deny destructive shell commands. Cursor beforeShellExecution hook."""
import json
import re
import sys

DENY_PATTERNS = [
    (re.compile(r"\bgit\s+push\b[^\n]*?(?:\s--force\b|\s-f\b)"), "git push --force"),
    (re.compile(r"\bgit\s+reset\s+--hard\b"), "git reset --hard"),
]

MSG = (
    "Blocked by project hook. Ask the user before force-push or hard reset."
)


def main():
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError:
        print(json.dumps({"permission": "deny", "agent_message": "Invalid hook input JSON."}))
        return 0

    command = payload.get("command") or ""
    for pattern, label in DENY_PATTERNS:
        if pattern.search(command):
            print(
                json.dumps(
                    {
                        "permission": "deny",
                        "user_message": f"Blocked {label}. Confirm with the user first.",
                        "agent_message": MSG + f" Matched: {label}.",
                    }
                )
            )
            return 0

    print(json.dumps({"permission": "allow"}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
