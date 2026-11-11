#!/usr/bin/env python3
"""Fail on hardcoded temp paths across repo scripts and tests unless allowlisted with a reason (Defect 2)."""

from __future__ import annotations

import os
import pathlib
import re
import sys
import tempfile


SCAN_EXTS = {".sh", ".zsh", ".lua", ".py"}
EXPLICIT_SCRIPTS = {
    "install.sh",
    "shell/zshrc",
    "shell/zshenv",
    "shell/bashrc_custom",
    "shell/omni-aliases.zsh",
}
SKIP_DIRS = {".git", "plugins", "fixtures", "__pycache__", ".cache"}

# Each allowlisted match requires an exact (relpath, substring): justification mapping.
# Every entry MUST match at least once on disk (stale entries fail verification).
_TMP_LIT = "/" + "tmp"
ALLOWLIST: dict[tuple[str, str], str] = {
    ("bin/devcheck", f"{_TMP_LIT}/dc-"): "devcheck allocates its outer log and private TMPDIR root in system tmp",
}

PAT_TMP_SUBPATH = re.compile(r"(?<!:-)/tmp/")
PAT_TMP_BARE_QUOTED = re.compile(r"""(['"])/tmp\1""")


def resolve_repo_root() -> pathlib.Path:
    env_root = os.environ.get("DOTFILES_REPO_ROOT")
    if env_root:
        return pathlib.Path(env_root).resolve()
    return pathlib.Path(__file__).resolve().parents[2]


def iter_target_files(repo_root: pathlib.Path) -> list[pathlib.Path]:
    found: set[pathlib.Path] = set()
    for rel in EXPLICIT_SCRIPTS:
        p = repo_root / rel
        if p.is_file():
            found.add(p)

    for top in ("bin", ".config", "tests", "shell"):
        base = repo_root / top
        if not base.is_dir():
            continue
        for root_str, dirs, files in os.walk(base):
            dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
            root_p = pathlib.Path(root_str)
            for fn in files:
                fp = root_p / fn
                if fp.suffix in SCAN_EXTS or (top == "bin" and os.access(fp, os.X_OK)):
                    found.add(fp)
    return sorted(found)


def scan_repo(repo_root: pathlib.Path, allowlist: dict[tuple[str, str], str]) -> tuple[list[str], set[tuple[str, str]]]:
    failures: list[str] = []
    used_allowlist: set[tuple[str, str]] = set()
    for fp in iter_target_files(repo_root):
        rel = fp.relative_to(repo_root).as_posix()
        try:
            text = fp.read_text(encoding="utf-8", errors="replace")
        except OSError as exc:
            failures.append(f"unreadable {rel}: {exc}")
            continue
        for lineno, line in enumerate(text.splitlines(), 1):
            has_match = bool(PAT_TMP_SUBPATH.search(line) or PAT_TMP_BARE_QUOTED.search(line))
            if not has_match:
                continue
            matched_keys = [k for k in allowlist if k[0] == rel and k[1] in line]
            if matched_keys:
                used_allowlist.update(matched_keys)
                continue
            failures.append(f"{rel}:{lineno}: un-allowlisted hardcoded /tmp reference: {line.strip()}")
    return failures, used_allowlist


def run_self_test() -> int:
    with tempfile.TemporaryDirectory(prefix="tmp-static-selftest-") as td:
        root = pathlib.Path(td)
        (root / "tests").mkdir()
        bad_script = root / "tests" / "bad.sh"
        bad_script.write_text(f"#!/bin/sh\necho hi > {_TMP_LIT}/leaked_file\n", encoding="utf-8")
        fails, _ = scan_repo(root, {})
        if not fails:
            print("FAIL: static /tmp scanner missed injected leak", file=sys.stderr)
            return 1
    print("PASS: static /tmp self-test caught injected leak")
    return 0


def main(argv: list[str] | None = None) -> int:
    args = sys.argv[1:] if argv is None else argv
    if args == ["--self-test"]:
        return run_self_test()
    if args:
        print("usage: check-no-hardcoded-tmp.py [--self-test]", file=sys.stderr)
        return 2

    repo_root = resolve_repo_root()
    if run_self_test() != 0:
        return 1

    # Self-exclude the two regex definitions inside this file by checking allowlist cleanly
    effective_allowlist = {
        **ALLOWLIST,
        ("tests/static/check-no-hardcoded-tmp.py", "PAT_TMP_"): "regex definitions for the banned /tmp literal patterns themselves",
    }
    failures, used = scan_repo(repo_root, effective_allowlist)
    unused = sorted(set(effective_allowlist) - used)
    for k in unused:
        failures.append(f"stale ALLOWLIST entry in check-no-hardcoded-tmp.py: {k}")

    if failures:
        for f in failures:
            print(f"FAIL: {f}", file=sys.stderr)
        return 1

    print(f"PASS: zero un-allowlisted hardcoded tmp paths ({len(used)} allowlisted entries verified)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
