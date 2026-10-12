#!/usr/bin/env python3
"""Deny read/write of secret files. Cursor beforeReadFile and preToolUse hook."""
import json
import os
import sys

ALLOW_SUFFIXES = (".env.example",)
PRIVATE_KEY_NAMES = {"id_rsa", "id_ed25519", "id_ecdsa", "id_dsa"}


def is_secret_path(path):
    if not path:
        return False
    name = os.path.basename(path.rstrip("/"))
    if not name:
        return False
    lower = name.lower()
    if any(lower.endswith(s) for s in ALLOW_SUFFIXES):
        return False
    if lower == ".env" or lower.startswith(".env."):
        return True
    if lower == "credentials.json":
        return True
    if "service-account" in lower and lower.endswith(".json"):
        return True
    if lower in PRIVATE_KEY_NAMES:
        return True
    if lower.endswith(".pem") or lower.endswith(".p12"):
        return True
    if lower.endswith(".key") and not lower.endswith(".pub"):
        return True
    return False


def paths_from_payload(payload):
    found: list[str] = []
    file_path = payload.get("file_path") or payload.get("filePath")
    if isinstance(file_path, str):
        found.append(file_path)

    tool_input = payload.get("tool_input") or {}
    if isinstance(tool_input, str):
        try:
            tool_input = json.loads(tool_input)
        except json.JSONDecodeError:
            tool_input = {}
    if isinstance(tool_input, dict):
        for key in ("path", "file_path", "filePath", "target_notebook"):
            value = tool_input.get(key)
            if isinstance(value, str):
                found.append(value)
    return found


def main():
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError:
        print(
            json.dumps(
                {
                    "permission": "deny",
                    "user_message": "Invalid hook input JSON.",
                    "agent_message": "Secret-file hook received invalid JSON.",
                }
            )
        )
        return 0

    secrets = [p for p in paths_from_payload(payload) if is_secret_path(p)]
    if secrets:
        shown = secrets[0]
        print(
            json.dumps(
                {
                    "permission": "deny",
                    "user_message": f"Blocked access to secret file: {shown}",
                    "agent_message": (
                        "Do not read or write .env (except .env.example), credentials.json, "
                        "service-account JSON, or private keys. Keep Wi-Fi/MQTT placeholders "
                        "in config.gleam; do not commit real passwords."
                    ),
                }
            )
        )
        return 0

    print(json.dumps({"permission": "allow"}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
