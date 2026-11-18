#!/usr/bin/env python3
"""Parse live terminal stack configs and enforce single-owner-per-signal rules (C4)."""

from __future__ import annotations

import ast
import os
import pathlib
import re
import sys
import tomllib


def resolve_repo_root() -> pathlib.Path:
    env_root = os.environ.get("DOTFILES_REPO_ROOT")
    if env_root:
        return pathlib.Path(env_root).resolve()
    return pathlib.Path(__file__).resolve().parents[2]


def parse_ownership_md(md_path: pathlib.Path) -> tuple[dict[tuple[str, str], str], set[tuple[str, str, str]]]:
    """Extract canonical matrix {(signal, context): owner} and allowlisted {(signal, context, emitter)}."""
    text = md_path.read_text(encoding="utf-8")
    matrix: dict[tuple[str, str], str] = {}
    allowlist: set[tuple[str, str, str]] = set()
    section = ""

    for raw in text.splitlines():
        line = raw.strip()
        if line.startswith("## "):
            section = line[3:].strip().lower()
            continue
        if not line.startswith("|") or line.startswith("| Signal") or line.startswith("| ---"):
            continue
        cols = [c.strip() for c in line.strip("|").split("|")]
        if len(cols) < 4:
            continue
        if section == "matrix":
            sig, ctx, owner, _ = cols[:4]
            matrix[(sig, ctx)] = owner
        elif section == "allowlisted exceptions":
            sig, ctx, emitter, _ = cols[:4]
            allowlist.add((sig, ctx, emitter))

    return matrix, allowlist


def collect_omp_emitters(cfg_root: pathlib.Path) -> tuple[dict[str, set[str]], list[str]]:
    """Inspect all OMP templates/configs for emitted signals."""
    errors: list[str] = []
    per_file: dict[str, set[str]] = {}
    omp_dir = cfg_root / "ohmyposh"
    paths = [omp_dir / "zen.toml", omp_dir / "zen-apple-glass.toml"]

    for p in paths:
        if not p.is_file():
            errors.append(f"missing OMP config: {p}")
            continue
        data = tomllib.loads(p.read_text(encoding="utf-8"))
        sigs: set[str] = set()
        for blk in data.get("blocks", []):
            for seg in blk.get("segments", []):
                stype = seg.get("type", "")
                if stype == "path":
                    sigs.add("cwd")
                elif stype == "git":
                    sigs.add("git")
        per_file[p.name] = sigs

    if per_file:
        first_name = next(iter(per_file))
        baseline = per_file[first_name]
        for fname, sigs in per_file.items():
            if sigs != baseline:
                errors.append(
                    f"OMP config drift between {first_name} ({sorted(baseline)}) and {fname} ({sorted(sigs)})"
                )
    union = set().union(*per_file.values()) if per_file else set()
    return {"ohmyposh": union}, errors


def collect_tmux_emitters(cfg_root: pathlib.Path) -> tuple[dict[str, set[str]], list[str]]:
    """Parse tmux.conf and status-right.sh to detect signal emitters."""
    errors: list[str] = []
    tmux_conf = cfg_root / "tmux" / "tmux.conf"
    sr_script = cfg_root / "tmux" / "scripts" / "status-right.sh"
    if not tmux_conf.is_file() or not sr_script.is_file():
        return {}, [f"missing tmux config or status-right.sh in {cfg_root / 'tmux'}"]

    conf_lines = tmux_conf.read_text(encoding="utf-8").splitlines()
    active_lines = [l for l in conf_lines if l.strip() and not l.lstrip().startswith("#")]
    status_left_blob = "\n".join(l for l in active_lines if re.search(r"\bstatus-left\b", l))
    status_right_blob = "\n".join(l for l in active_lines if re.search(r"\bstatus-right\b", l))
    win_status_blob = "\n".join(
        l for l in active_lines if re.search(r"\bwindow-status-(current-)?format\b|\bautomatic-rename-format\b", l)
    )
    pane_border_blob = "\n".join(l for l in active_lines if re.search(r"\bpane-border-format\b", l))

    emitters: dict[str, set[str]] = {
        "tmux:status-left": set(),
        "tmux:status-right": set(),
        "tmux:window-status": set(),
        "tmux:pane-border-format": set(),
    }

    if "pane_current_path" in status_left_blob:
        emitters["tmux:status-left"].add("cwd")
    if "pane_current_command" in status_left_blob:
        emitters["tmux:status-left"].add("pane_command")

    if "#{W}" in win_status_blob or "#W" in win_status_blob or "pane_current_command" in win_status_blob:
        emitters["tmux:window-status"].add("pane_command")

    if "pane_current_command" in pane_border_blob:
        emitters["tmux:pane-border-format"].add("pane_command")

    sr_text = sr_script.read_text(encoding="utf-8")
    if "status-right.sh" in status_right_blob:
        if "git_info" in sr_text:
            emitters["tmux:status-right"].add("git")
        if re.search(r"agents\b|get_active_agents", sr_text):
            emitters["tmux:status-right"].add("agents")
        if re.search(r"containers\b|podman|docker", sr_text):
            emitters["tmux:status-right"].add("containers")

    return emitters, errors


def _ast_called_names(stmts: list[ast.stmt]) -> set[str]:
    names: set[str] = set()
    for s in stmts:
        for node in ast.walk(s):
            if isinstance(node, ast.Call) and isinstance(node.func, ast.Name):
                names.add(node.func.id)
    return names


def collect_kitty_emitters(cfg_root: pathlib.Path) -> tuple[dict[str, set[str]], dict[str, set[str]], list[str]]:
    """Inspect kitty/tab_bar.py AST to separate tmux-mode vs bare-mode emissions."""
    errors: list[str] = []
    tb_path = cfg_root / "kitty" / "tab_bar.py"
    if not tb_path.is_file():
        return {}, {}, [f"missing {tb_path}"]

    tree = ast.parse(tb_path.read_text(encoding="utf-8"))
    top_defs = {n.name for n in tree.body if isinstance(n, ast.FunctionDef)}
    if "format_breadcrumb" in top_defs:
        errors.append("kitty/tab_bar.py still defines legacy format_breadcrumb() (C4)")

    draw_fn = next(
        (n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == "draw_right_status"),
        None,
    )
    if draw_fn is None:
        return {}, {}, ["kitty/tab_bar.py missing draw_right_status()"]

    tmux_calls: set[str] = set()
    bare_calls: set[str] = set()
    always_calls: set[str] = set()

    for stmt in draw_fn.body:
        if (
            isinstance(stmt, ast.If)
            and isinstance(stmt.test, ast.Name)
            and stmt.test.id == "tmux_sess"
        ):
            tmux_calls |= _ast_called_names(stmt.body)
            bare_calls |= _ast_called_names(stmt.orelse)
        else:
            always_calls |= _ast_called_names([stmt])

    def map_calls(calls: set[str]) -> set[str]:
        out: set[str] = set()
        if "get_git_info" in calls:
            out.add("git")
        if "format_breadcrumb" in calls:
            out.add("cwd")
        if "get_active_agents" in calls:
            out.add("agents")
        if "get_containers" in calls:
            out.add("containers")
        if "get_battery" in calls:
            out.add("battery")
        if "get_clock" in calls:
            out.add("clock")
        return out

    return (
        {"kitty:tab_bar": map_calls(always_calls | tmux_calls)},
        {"kitty:tab_bar": map_calls(always_calls | bare_calls)},
        errors,
    )


def collect_wezterm_emitters(cfg_root: pathlib.Path) -> tuple[dict[str, set[str]], list[str]]:
    """Inspect WezTerm tab-title.lua, right-status.lua, and hud.lua for signal ownership."""
    errors: list[str] = []
    tab_title_p = cfg_root / "wezterm" / "events" / "tab-title.lua"
    right_p = cfg_root / "wezterm" / "events" / "right-status.lua"
    hud_p = cfg_root / "wezterm" / "events" / "hud.lua"
    for p in (tab_title_p, right_p, hud_p):
        if not p.is_file():
            return {}, [f"missing {p}"]

    tt_text = tab_title_p.read_text(encoding="utf-8")
    rs_text = right_p.read_text(encoding="utf-8")
    hud_text = hud_p.read_text(encoding="utf-8")

    emitters: dict[str, set[str]] = {
        "wezterm:tab-title": set(),
        "wezterm:tab-title:no-osc7": set(),
        "wezterm:right-status": set(),
        "wezterm:hud": set(),
    }

    # Check whether compose_title prefixes cwd when OSC 7 is present
    m_comp = re.search(r"local function compose_title\(.*?\n(.*?\n)end", tt_text, re.S)
    if not m_comp:
        errors.append("wezterm/events/tab-title.lua missing compose_title()")
    else:
        body = m_comp.group(1)
        if re.search(r"\bcwd_basename\b|dir\s*\.\.\s*['\"] ~ ['\"]", body):
            emitters["wezterm:tab-title"].add("cwd")
        if "process_name .. ' ~ ' .. base_title" in body:
            emitters["wezterm:tab-title:no-osc7"].add("fallback_title")

    if "battery_info" in rs_text or "battery_text" in rs_text:
        emitters["wezterm:right-status"].add("battery")
    if "clock_text" in rs_text:
        emitters["wezterm:right-status"].add("clock")
    if "get_git_info" in rs_text or "get_git_info" in hud_text:
        emitters["wezterm:hud"].add("git")

    return emitters, errors


def main() -> int:
    repo_root = resolve_repo_root()
    cfg_root = pathlib.Path(os.environ.get("DOTFILES_CONFIG_ROOT", repo_root / ".config"))
    md_path = repo_root / "tests" / "signals" / "ownership.md"
    if not md_path.is_file():
        print(f"FAIL: missing ownership matrix {md_path}", file=sys.stderr)
        return 1

    matrix, allowlist = parse_ownership_md(md_path)
    if not matrix:
        print(f"FAIL: parsed 0 matrix rows from {md_path}", file=sys.stderr)
        return 1

    omp_em, omp_errs = collect_omp_emitters(cfg_root)
    tmux_em, tmux_errs = collect_tmux_emitters(cfg_root)
    kt_tmux_em, kt_bare_em, kt_errs = collect_kitty_emitters(cfg_root)
    wz_em, wz_errs = collect_wezterm_emitters(cfg_root)

    failures: list[str] = [*omp_errs, *tmux_errs, *kt_errs, *wz_errs]

    # Normalize OMP emitter label 'ohmyposh:path' / 'ohmyposh:git' so owners stay fine-grained
    omp_mapped: dict[str, set[str]] = {}
    if "cwd" in omp_em.get("ohmyposh", set()):
        omp_mapped["ohmyposh:path"] = {"cwd"}
    if "git" in omp_em.get("ohmyposh", set()):
        omp_mapped["ohmyposh:git"] = {"git"}

    contexts: dict[str, dict[str, set[str]]] = {
        "kitty+tmux": {**omp_mapped, **tmux_em, **kt_tmux_em},
        "bare-kitty": {**omp_mapped, **kt_bare_em},
        "wezterm+shell": {**omp_mapped, **wz_em},
    }

    checked = 0
    for (sig, ctx), expected_owner in matrix.items():
        if ctx not in contexts:
            failures.append(f"unknown host context in ownership.md: {ctx}")
            continue
        checked += 1
        active: list[str] = []
        for emitter_name, sigs in contexts[ctx].items():
            if sig in sigs:
                if (sig, ctx, emitter_name) in allowlist:
                    continue
                active.append(emitter_name)

        if len(active) > 1:
            failures.append(
                f"duplicate owners for signal '{sig}' in context '{ctx}': {sorted(active)} "
                f"(expected single owner '{expected_owner}')"
            )
        elif expected_owner == "none":
            if active:
                failures.append(
                    f"signal '{sig}' in context '{ctx}' expected no owner ('none'), found {sorted(active)}"
                )
        elif active != [expected_owner]:
            failures.append(
                f"signal '{sig}' in context '{ctx}' owner mismatch: active={sorted(active)}, expected=['{expected_owner}']"
            )

    # Verify every allowlisted secondary emitter exists as documented (prevent stale allowlist)
    for sig, ctx, emitter_name in sorted(allowlist):
        if ctx not in contexts:
            failures.append(f"stale allowlist context '{ctx}'")
            continue
        if sig not in contexts[ctx].get(emitter_name, set()):
            failures.append(
                f"documented exception ({sig}, {ctx}, {emitter_name}) is no longer active in configs; update ownership.md"
            )

    if failures:
        for msg in failures:
            print(f"FAIL: {msg}", file=sys.stderr)
        return 1

    print(f"PASS: signal ownership verified ({checked} matrix entries, {len(allowlist)} documented exceptions, 0 duplicates)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
