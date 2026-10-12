#!/usr/bin/env python3
"""Format a file after Agent edit. Fail open if tools are missing. Cursor afterFileEdit hook."""
import json
import os
import shutil
import subprocess
import sys

TIMEOUT = 30


def walk_up_for(start, names):
    directory = os.path.dirname(os.path.abspath(start))
    while True:
        for name in names:
            candidate = os.path.join(directory, name)
            if os.path.isfile(candidate):
                return directory
        parent = os.path.dirname(directory)
        if parent == directory:
            return None
        directory = parent


def run(cmd, cwd):
    subprocess.run(
        cmd,
        cwd=cwd,
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        timeout=TIMEOUT,
    )


def format_file(path):
    ext = os.path.splitext(path)[1].lower()
    if ext == ".gleam":
        root = walk_up_for(path, ("gleam.toml",))
        gleam = shutil.which("gleam")
        if root and gleam:
            run([gleam, "format", path], root)


def main():
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError:
        return 0
    path = payload.get("file_path") or payload.get("filePath") or ""
    if path and os.path.isfile(path):
        try:
            format_file(path)
        except (OSError, subprocess.SubprocessError, subprocess.TimeoutExpired):
            pass
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
