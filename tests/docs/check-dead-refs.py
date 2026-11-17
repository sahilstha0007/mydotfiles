#!/usr/bin/env python3
"""Scan shell files, configs, bin scripts, and docs for dead binary/path references (D6)."""

from __future__ import annotations

import os
import pathlib
import re
import shutil
import sys


def resolve_repo_root() -> pathlib.Path:
    env_root = os.environ.get("DOTFILES_REPO_ROOT")
    if env_root:
        return pathlib.Path(env_root).resolve()
    return pathlib.Path(__file__).resolve().parents[2]


def path_exists(raw: str, repo_root: pathlib.Path, home: pathlib.Path) -> bool:
    expanded = raw.replace("$HOME", str(home)).replace("${HOME}", str(home))
    if expanded.startswith("~/"):
        expanded = str(home / expanded[2:])
    if pathlib.Path(expanded).exists():
        return True
    for prefix in ("~/.config/", "~/.local/", "~/mydotfiles/", "~/.zshrc", "~/.zshenv", "~/.bashrc_custom"):
        if raw.startswith(prefix):
            rel = raw[2:]
            if rel.startswith("mydotfiles/"):
                rel = rel[len("mydotfiles/") :]
            if rel.startswith(".local/bin/"):
                if (repo_root / "bin" / rel[len(".local/bin/") :]).exists():
                    return True
            if (repo_root / rel).exists():
                return True
    return False


def scan_shell(repo_root: pathlib.Path, home: pathlib.Path) -> list[str]:
    fails: list[str] = []
    banned_dead_cmds = ("jcode",)
    shell_files = [
        repo_root / "shell" / "zshrc",
        repo_root / "shell" / "zshenv",
        repo_root / "shell" / "bashrc_custom",
    ]
    builtins_or_special = {
        "cd",
        "clear",
        "command",
        "builtin",
        "exec",
        "podman",
        "$EDITOR",
        "git",
        "/usr/bin/git",
        "ls",
    }

    for p in shell_files:
        if not p.is_file():
            fails.append(f"missing shell file: {p}")
            continue
        lines = p.read_text(encoding="utf-8").splitlines()
        in_guard = False
        for i, line in enumerate(lines, 1):
            stripped = line.strip()
            if stripped.startswith("#"):
                continue

            for bad in banned_dead_cmds:
                if re.search(rf"\b{re.escape(bad)}\b", line):
                    fails.append(f"{p.relative_to(repo_root)}:{i}: dead command reference '{bad}'")

            if re.match(r"^(if|elif)\s+.*(command -v|\+\$commands\[|\[ -[dfexr] )", stripped):
                in_guard = True
            elif stripped == "fi":
                in_guard = False

            # Check alias targets (e.g. alias v='nvim', alias pt='$HOME/.local/bin/project-task')
            m_alias = re.match(r"""^alias\s+[A-Za-z0-9_.-]+=(['"])([^'"]+)\1""", stripped)
            if m_alias and not in_guard:
                cmd_tok = m_alias.group(2).split()[0]
                if cmd_tok in builtins_or_special or cmd_tok.startswith("$EDITOR"):
                    continue
                if "$HOME" in cmd_tok or cmd_tok.startswith("~/"):
                    mapped = cmd_tok.replace("$HOME/.local/bin/", "~/.local/bin/").replace("$HOME/.config/", "~/.config/")
                    if not path_exists(mapped, repo_root, home):
                        fails.append(f"{p.relative_to(repo_root)}:{i}: alias target path missing: {cmd_tok}")
                elif not shutil.which(cmd_tok):
                    fails.append(f"{p.relative_to(repo_root)}:{i}: alias target command missing on PATH: {cmd_tok}")

    return fails


def scan_configs_and_bin(repo_root: pathlib.Path, home: pathlib.Path) -> list[str]:
    fails: list[str] = []
    # Validate kitty includes and kittens
    kitty_dir = repo_root / ".config" / "kitty"
    for conf_name in ("kitty.conf", "custom.conf"):
        cf = kitty_dir / conf_name
        if not cf.is_file():
            continue
        for i, line in enumerate(cf.read_text(encoding="utf-8").splitlines(), 1):
            s = line.strip()
            if not s or s.startswith("#"):
                continue
            m_inc = re.match(r"^include\s+(\S+)$", s)
            if m_inc:
                inc_raw = m_inc.group(1)
                inc_clean = inc_raw.replace("$HOME/.config/kitty/", "").replace("${HOME}/.config/kitty/", "")
                target = kitty_dir / inc_clean if "/" not in inc_clean or not inc_raw.startswith(("/", "$", "~")) else None
                if inc_raw.startswith(("$HOME/.config/", "${HOME}/.config/", "~/.config/")):
                    mapped = inc_raw.replace("${HOME}", "~").replace("$HOME", "~")
                    if not path_exists(mapped, repo_root, home):
                        fails.append(f".config/kitty/{conf_name}:{i}: missing include target {inc_raw}")
                elif target is not None and not target.exists():
                    fails.append(f".config/kitty/{conf_name}:{i}: missing include {inc_raw}")
                elif inc_raw.startswith("/") and not pathlib.Path(inc_raw).exists():
                    fails.append(f".config/kitty/{conf_name}:{i}: missing absolute include {inc_raw}")

            m_kit = re.search(r"\bkitten\s+([^\s]+\.py)\b", s)
            if m_kit and not (kitty_dir / m_kit.group(1)).is_file():
                fails.append(f".config/kitty/{conf_name}:{i}: missing kitten script {m_kit.group(1)}")

    # Validate tmux unguarded script hooks
    tmux_conf = repo_root / ".config" / "tmux" / "tmux.conf"
    if tmux_conf.is_file():
        pat_tmux = re.compile(r"(~/.config/tmux/[^\s'\"]+|~/.local/bin/[^\s'\"]+)")
        for i, line in enumerate(tmux_conf.read_text(encoding="utf-8").splitlines(), 1):
            s = line.strip()
            if not s or s.startswith("#"):
                continue
            for m in pat_tmux.finditer(s):
                raw = m.group(1)
                if "if-shell" in s or "[ -x " in s or "[ -f " in s or "[ -e " in s or "plugins/tpm" in raw:
                    continue
                if not path_exists(raw, repo_root, home):
                    fails.append(f".config/tmux/tmux.conf:{i}: missing script/bin {raw}")

    return fails


def scan_docs(repo_root: pathlib.Path, home: pathlib.Path) -> list[str]:
    fails: list[str] = []
    doc_files: list[pathlib.Path] = [repo_root / "README.md"] + sorted((repo_root / ".config" / "nvim" / "docs").glob("*.md"))
    atlas_dir = pathlib.Path(os.environ.get("ATLAS_DIR", str(home / "Documents/Notes/Atlas")))
    if os.environ.get("DEVCHECK_IN_CLEAN_CLONE") != "1":
        for name in ("08 - Keybindings Master Reference.md", "Terminal Stack Home.md"):
            p = atlas_dir / "02 - Dev" / "Terminal Stack" / name
            if p.is_file():
                doc_files.append(p)

    pat = re.compile(r"`((?:~/.config|~/.local/bin|~/mydotfiles|~/config)[^`\s]+)`")
    skip_external = ("~/.config/ml4w/hypr/custom.lua",)
    for p in doc_files:
        if not p.is_file():
            continue
        for i, line in enumerate(p.read_text(encoding="utf-8").splitlines(), 1):
            for m in pat.finditer(line):
                raw = m.group(1).rstrip(".,:)")
                if raw.startswith("~/config"):
                    fails.append(f"{p}:{i}: typo path '{raw}' (missing dot in .config)")
                    continue
                if raw in skip_external or any(ch in raw for ch in ("*", "<", ">", "{", "}", "…", "$")):
                    continue
                if not path_exists(raw, repo_root, home):
                    fails.append(f"{p}:{i}: dead documented path '{raw}'")
    return fails


def main() -> int:
    repo_root = resolve_repo_root()
    home = pathlib.Path.home()
    fails = [*scan_shell(repo_root, home), *scan_configs_and_bin(repo_root, home), *scan_docs(repo_root, home)]
    if fails:
        for msg in fails:
            print(f"FAIL: {msg}", file=sys.stderr)
        return 1
    print("PASS: zero dead binary or path references across shell, configs, and docs")
    return 0


if __name__ == "__main__":
    sys.exit(main())
