#!/usr/bin/env python3
"""State-matrix invariance gate (Class fix): verify key gates pass identically across 5 environment states.

States verified:
  1. empty_tmp             -- fresh empty TMPDIR, standard XDG_RUNTIME_DIR, empty .zshrc.local
  2. populated_tmp         -- TMPDIR pre-populated with probe_repo and leak decoys (assert zero interference/leaks)
  3. fresh_matugen         -- sandbox matugen + cascade generators (incl. /* */ kitty comment + sanitizer)
  4. missing_zshrc_local   -- $HOME/.zshrc.local absent
  5. unset_xdg_runtime_dir -- XDG_RUNTIME_DIR unset

Any gate failure in any state, any new temp leak, or ANY result divergence across states is a defect (exit 1).
"""

from __future__ import annotations

import os
import pathlib
import shutil
import subprocess
import sys
import tempfile
import time


STATES = (
    "empty_tmp",
    "populated_tmp",
    "fresh_matugen",
    "missing_zshrc_local",
    "unset_xdg_runtime_dir",
)


def resolve_repo_root() -> pathlib.Path:
    env_root = os.environ.get("DOTFILES_REPO_ROOT")
    if env_root:
        return pathlib.Path(env_root).resolve()
    return pathlib.Path(__file__).resolve().parents[2]


def build_sandbox_path(real_home: str) -> str:
    extras = [
        os.path.join(real_home, ".local/share/mise/shims"),
        os.path.join(real_home, ".local/share/nvim/mason/bin"),
        os.path.join(real_home, ".luarocks/bin"),
    ]
    present = [d for d in extras if os.path.isdir(d)]
    base = os.environ.get("PATH", "/usr/bin:/bin")
    return ":".join([*present, base]) if present else base


def snapshot_tree_rel(d: pathlib.Path) -> set[str]:
    if not d.is_dir():
        return set()
    entries: set[str] = set()
    nvim_parent = f"nvim.{os.environ.get('USER') or pathlib.Path.home().name}"
    for root_str, dirs, files in os.walk(d):
        root_p = pathlib.Path(root_str)
        for name in [*dirs, *files]:
            rel = (root_p / name).relative_to(d).as_posix()
            # Upstream Neovim C core creates an empty $TMPDIR/nvim.<user> parent directory and never unlinks it;
            # any children inside nvim.<user> or any other file/dir are still treated strictly as leaks.
            if rel == nvim_parent and (root_p / name).is_dir() and not any((root_p / name).iterdir()):
                continue
            entries.add(rel)
    return entries


def seed_base_state(repo_src: pathlib.Path, work: pathlib.Path, real_home: str, base_path: str) -> tuple[pathlib.Path, pathlib.Path]:
    base_repo = work / "base_repo"
    base_home = work / "base_home"
    base_tmp = work / "base_tmp"
    base_home.mkdir(parents=True)
    base_tmp.mkdir(parents=True)
    subprocess.run(["git", "clone", "--quiet", str(repo_src), str(base_repo)], check=True)
    env = {
        "HOME": str(base_home),
        "PATH": base_path,
        "MISE_DATA_DIR": os.environ.get("MISE_DATA_DIR", os.path.join(real_home, ".local/share/mise")),
        "MISE_CONFIG_DIR": os.environ.get("MISE_CONFIG_DIR", os.path.join(real_home, ".config/mise")),
        "TMPDIR": str(base_tmp),
    }
    subprocess.run(["bash", str(base_repo / "install.sh")], env=env, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    # Pre-seed lazy plugins once so per-state nvim_keymaps runs deterministically without 5x network fetches
    subprocess.run(["make", "-C", str(base_repo / ".config/nvim"), "keymaps"], env=env, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    # Seed non-secret empty .zshrc.local in baseline so missing_zshrc_local contrasts cleanly
    (base_home / ".zshrc.local").write_text("# test non-secret placeholder\n", encoding="utf-8")
    return base_repo, base_home


def clone_state(base_repo: pathlib.Path, base_home: pathlib.Path, state_dir: pathlib.Path, sb_path: str, real_home: str) -> tuple[pathlib.Path, pathlib.Path, dict[str, str]]:
    st_repo = state_dir / "repo"
    st_home = state_dir / "home"
    st_tmp = state_dir / "tmp"
    st_xdg = state_dir / "xdg"
    shutil.copytree(base_repo, st_repo, symlinks=True)
    shutil.copytree(base_home, st_home, symlinks=True)
    st_tmp.mkdir(parents=True)
    st_xdg.mkdir(parents=True)
    os.chmod(st_xdg, 0o700)

    # Re-point symlinks inside st_home that pointed into base_repo so they point to st_repo
    base_repo_resolved = base_repo.resolve()
    for dirpath, dirnames, filenames in os.walk(st_home):
        for name in [*dirnames, *filenames]:
            p = pathlib.Path(dirpath) / name
            if p.is_symlink():
                target = pathlib.Path(os.readlink(p))
                try:
                    rel = target.resolve().relative_to(base_repo_resolved)
                except ValueError:
                    continue
                p.unlink()
                p.symlink_to(st_repo / rel)

    env = {
        "HOME": str(st_home),
        "PATH": f"{st_home / '.local/bin'}:{sb_path}",
        "TMPDIR": str(st_tmp),
        "XDG_RUNTIME_DIR": str(st_xdg),
        "MISE_DATA_DIR": os.environ.get("MISE_DATA_DIR", os.path.join(real_home, ".local/share/mise")),
        "MISE_CONFIG_DIR": os.environ.get("MISE_CONFIG_DIR", os.path.join(real_home, ".config/mise")),
        "TERM": os.environ.get("TERM", "xterm-256color"),
    }
    return st_repo, st_home, env


def prepare_state(state: str, st_repo: pathlib.Path, st_home: pathlib.Path, st_dir: pathlib.Path, env: dict[str, str]) -> set[str]:
    st_tmp = st_dir / "tmp"
    if state == "populated_tmp":
        probe = st_tmp / "probe_repo"
        (probe / ".git").mkdir(parents=True)
        (probe / "main.py").write_text("x = 1\n", encoding="utf-8")
        (st_tmp / "nvim.sahil").mkdir()
        (st_tmp / "go-build999999").mkdir()
        (st_tmp / "dotfiles-sandbox.decoy").mkdir()
        (st_tmp / "tmp.decoy.out").write_text("decoy\n", encoding="utf-8")
        (st_tmp / "ccDecoy.s").write_text("decoy\n", encoding="utf-8")
    elif state == "fresh_matugen":
        wall = st_repo / "tests/wezterm/fixtures/wall-a.png"
        wez_tpl = st_repo / "tests/wezterm/fixtures/wezterm-colors.lua"
        kit_tpl = st_dir / "kitty-colors.tpl"
        kit_tpl.write_text(
            "cursor {{colors.on_surface.default.hex}}\n"
            "cursor_text_color {{colors.on_surface_variant.default.hex}}\n"
            "foreground {{colors.on_surface.default.hex}}\n"
            "background {{colors.surface.default.hex}}\n"
            "selection_foreground {{colors.on_secondary.default.hex}}\n"
            "selection_background {{colors.secondary_fixed_dim.default.hex}}\n"
            "url_color {{colors.primary.default.hex}}\n"
            "# blue\n"
            "/* color4 #8f8aac */\n"
            "color4 {{colors.primary.default.hex}}\n"
            "color5 {{colors.error.default.hex}}\n",
            encoding="utf-8",
        )
        m_toml = st_dir / "matugen.toml"
        m_toml.write_text(
            "[config]\n"
            "[templates.wezterm]\n"
            f"input_path = '{wez_tpl}'\n"
            f"output_path = '{st_home / '.config/wezterm/colors/matugen.lua'}'\n"
            "[templates.kitty]\n"
            f"input_path = '{kit_tpl}'\n"
            f"output_path = '{st_home / '.config/kitty/colors-matugen.conf'}'\n",
            encoding="utf-8",
        )
        subprocess.run(
            ["matugen", "-c", str(m_toml), "image", str(wall), "--prefer", "saturation", "--type", "scheme-tonal-spot", "-m", "smart"],
            env=env,
            check=True,
            capture_output=True,
            text=True,
        )
        subprocess.run(["bash", str(st_home / ".config/tmux/colors-from-matugen.sh")], env=env, check=True, capture_output=True)
        subprocess.run(["bash", str(st_home / ".config/ohmyposh/omp-palette.sh")], env=env, check=True, capture_output=True)
        subprocess.run(["bash", str(st_home / ".config/wezterm/utils/zsh-highlight-sync.sh")], env=env, check=True, capture_output=True)
        subprocess.run(
            [
                str(st_repo / "bin/kitty-colors-sanitize"),
                "--sync-in",
                "--in",
                str(st_home / ".config/kitty/colors-matugen.conf"),
                "--out",
                str(st_home / ".config/kitty/colors-matugen.validated.conf"),
            ],
            env=env,
            check=True,
            capture_output=True,
        )
    elif state == "missing_zshrc_local":
        (st_home / ".zshrc.local").unlink(missing_ok=True)
    elif state == "unset_xdg_runtime_dir":
        env.pop("XDG_RUNTIME_DIR", None)

    return snapshot_tree_rel(st_tmp)


def run_gate(cmd: list[str], cwd: pathlib.Path, env: dict[str, str], check_fn=None) -> tuple[bool, str]:
    t0 = time.perf_counter()
    proc = subprocess.run(cmd, cwd=str(cwd), env=env, capture_output=True, text=True)
    ms = (time.perf_counter() - t0) * 1000.0
    if proc.returncode != 0:
        detail = (proc.stderr or proc.stdout).strip().splitlines()[-3:]
        return False, f"exit {proc.returncode}: {' | '.join(detail)}"
    if check_fn is not None:
        ok, msg = check_fn(proc, ms)
        if not ok:
            return False, msg
    return True, f"{ms:.0f}ms"


def run_state_checks(state: str, st_repo: pathlib.Path, st_home: pathlib.Path, st_dir: pathlib.Path, env: dict[str, str], pre_tmp: set[str]) -> dict[str, tuple[bool, str]]:
    out: dict[str, tuple[bool, str]] = {}
    st_tmp = st_dir / "tmp"

    out["zsh_syntax"] = run_gate(["zsh", "-n", str(st_home / ".zshrc"), str(st_home / ".zshenv")], st_home, env)

    def _chk_zsh(_proc, ms: float) -> tuple[bool, str]:
        if ms > 120.0:
            return False, f"startup {ms:.1f}ms > 120ms"
        return True, f"{ms:.1f}ms"

    out["zsh_startup"] = run_gate(["zsh", "-i", "-c", "exit"], st_home, env, _chk_zsh)
    out["nvim_keymaps"] = run_gate(["make", "-C", str(st_repo / ".config/nvim"), "keymaps"], st_repo, env)
    out["kitty_sanitize"] = run_gate(["bash", str(st_repo / "tests/kitty/check-colors-sanitize.sh")], st_repo / ".config/kitty", env)
    out["kitty_parse"] = run_gate(
        [
            "kitty",
            "+runpy",
            "import sys; from kitty.config import load_config; bad=[]; load_config(sys.argv[1], accumulate_bad_lines=bad); sys.exit(1 if bad else 0)",
            str(st_repo / ".config/kitty/kitty.conf"),
        ],
        st_repo / ".config/kitty",
        env,
        lambda p, ms: ((not p.stderr.strip()), p.stderr.strip() or f"{ms:.0f}ms"),
    )
    out["wezterm_theme"] = run_gate(["luajit", str(st_repo / "tests/wezterm/check_theme_source.lua"), str(st_repo / ".config/wezterm")], st_repo / ".config/wezterm", env)
    out["tmux_reload"] = run_gate(["bash", str(st_repo / "tests/tmux/check-reload-idempotency.sh")], st_repo, env)
    out["contrast_wcag"] = run_gate(["python3", str(st_repo / "tests/contrast/check-contrast.py")], st_repo, env)

    # Assert temp directory remained strictly invariant across non-cache gates (including populated_tmp decoys)
    post_tmp = snapshot_tree_rel(st_tmp)
    leaked = sorted(post_tmp - pre_tmp)
    missing = sorted(pre_tmp - post_tmp)
    if leaked or missing:
        out["tmp_invariant"] = (False, f"+{leaked} -{missing}")
    else:
        out["tmp_invariant"] = (True, f"{len(post_tmp)} kept")

    # Run status-right after tmp_invariant so unset XDG_RUNTIME_DIR proves fallback uses $TMPDIR, not host tmp
    def _chk_sr(_proc, ms: float) -> tuple[bool, str]:
        if state == "unset_xdg_runtime_dir":
            expected_cache = st_tmp / f"tmux-status-{os.getuid()}"
            if not expected_cache.is_dir():
                return False, "cache did not fall back to $TMPDIR"
        return True, f"{ms:.0f}ms"

    out["tmux_status_right"] = run_gate(["bash", str(st_repo / ".config/tmux/scripts/status-right.sh")], st_repo / ".config/tmux", env, _chk_sr)
    return out


def assert_invariance(matrix: dict[str, dict[str, tuple[bool, str]]]) -> int:
    gates = list(next(iter(matrix.values())).keys())
    col_w = 22
    header = f"  {'Gate':<22} " + " ".join(f"{s:<{col_w}}" for s in STATES)
    print(header)
    print("  " + "-" * (len(header) - 2))
    failed_any = False
    variance_found = []
    for g in gates:
        statuses = set()
        cells = []
        for s in STATES:
            ok, note = matrix[s][g]
            statuses.add(ok)
            if not ok:
                failed_any = True
            tag = "PASS" if ok else "FAIL"
            cells.append(f"{f'{tag}({note[:13]})':<{col_w}}")
        if len(statuses) > 1:
            variance_found.append(g)
        print(f"  {g:<22} " + " ".join(cells))

    if variance_found:
        print(f"\nFAIL: state variance detected across states for gates: {', '.join(variance_found)}", file=sys.stderr)
        return 1
    if failed_any:
        print("\nFAIL: one or more gates failed in state matrix", file=sys.stderr)
        for s in STATES:
            for g, (ok, note) in matrix[s].items():
                if not ok:
                    print(f"  [{s}] {g}: {note}", file=sys.stderr)
        return 1
    print(f"\nPASS: state matrix invariant ({len(gates)} gates x {len(STATES)} states, 0 failures, 0 variance)")
    return 0


def run_self_test() -> int:
    # Prove assert_invariance returns 1 on state divergence (e.g. FAIL in unset_xdg_runtime_dir only)
    sample = {s: {"demo_gate": (True, "10ms")} for s in STATES}
    sample["unset_xdg_runtime_dir"]["demo_gate"] = (False, "simulated xdg crash")
    rc = assert_invariance(sample)
    if rc == 0:
        print("FAIL: state matrix invariance checker stayed GREEN on divergent gate", file=sys.stderr)
        return 1
    print("PASS: state matrix self-test caught cross-state divergence")
    return 0


def main(argv: list[str] | None = None) -> int:
    args = sys.argv[1:] if argv is None else argv
    if args == ["--self-test"]:
        return run_self_test()
    if args:
        print("usage: check-state-matrix.py [--self-test]", file=sys.stderr)
        return 2

    repo_root = resolve_repo_root()
    real_home = os.environ["HOME"]
    sb_path = build_sandbox_path(real_home)

    with tempfile.TemporaryDirectory(prefix="state-matrix-") as td:
        work = pathlib.Path(td)
        base_repo, base_home = seed_base_state(repo_root, work, real_home, sb_path)
        matrix: dict[str, dict[str, tuple[bool, str]]] = {}

        for state in STATES:
            st_dir = work / f"st_{state}"
            st_repo, st_home, env = clone_state(base_repo, base_home, st_dir, sb_path, real_home)
            pre_tmp = prepare_state(state, st_repo, st_home, st_dir, env)
            matrix[state] = run_state_checks(state, st_repo, st_home, st_dir, env, pre_tmp)

        return assert_invariance(matrix)


if __name__ == "__main__":
    sys.exit(main())
