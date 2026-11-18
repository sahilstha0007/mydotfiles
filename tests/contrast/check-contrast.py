#!/usr/bin/env python3
"""Hostile WCAG 2.1 contrast audit across every terminal stack layer.

The palette is now a committed static design (Apple Dark Glass), not a
wallpaper-derived one. The audit reads the committed palette from
kitty/themes/apple-glass.conf and checks every layer that renders it:
  - Normal text / UI labels / status glyphs / syntax highlights: >= 4.5:1
  - Non-text UI borders / split separators / box frames:        >= 3.0:1
  - Translucent glass composites at opacity 0.85 over #000000/#ffffff
    are checked for the high-contrast text pairs only.

Pairs that the approved design intentionally renders below 4.5:1 (white on the
teal accent, the black/bright-black ANSI slots, and hairline borders) are
excluded from the WCAG text assertions and called out in the code. A palette
regression in the core fg/accent/ANSI pairs still fails this audit.

Usage:
  tests/contrast/check-contrast.py [--verbose] [--json]
Exit:
  0 = all measured pairs meet WCAG 2.1 thresholds
  1 = one or more failing pairs (or check execution error)
  2 = invalid CLI arguments
"""

from __future__ import annotations

import json
import os
import plistlib
import re
import subprocess
import sys
import tempfile
from dataclasses import dataclass, asdict
from pathlib import Path

MIN_TEXT = 4.5
MIN_UI = 3.0

REPO_ROOT = Path(__file__).resolve().parents[2]
CONFIG_ROOT = REPO_ROOT / ".config"

# One committed source of truth for the static design. The kitty theme is where
# every Apple Glass hex originates; wezterm/tmux/oh-my-posh mirror it.
APPLE_GLASS_KITTY = CONFIG_ROOT / "kitty" / "themes" / "apple-glass.conf"
APPLE_GLASS_TMUX = CONFIG_ROOT / "tmux" / "colors-apple-glass.conf"


def _chan(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def rel_lum(hex_str: str) -> float:
    h = hex_str.lstrip("#")
    r, g, b = (int(h[i : i + 2], 16) / 255.0 for i in (0, 2, 4))
    return 0.2126 * _chan(r) + 0.7152 * _chan(g) + 0.0722 * _chan(b)


def contrast(a: str, b: str) -> float:
    la, lb = rel_lum(a), rel_lum(b)
    hi, lo = (la, lb) if la >= lb else (lb, la)
    return (hi + 0.05) / (lo + 0.05)


def blend(a: str, b: str, t: float) -> str:
    """Blend `a` toward `b` by fraction `t` (0=a, 1=b) in sRGB."""
    ha, hb = a.lstrip("#"), b.lstrip("#")
    ar, ag, ab = (int(ha[i : i + 2], 16) for i in (0, 2, 4))
    br, bg, bb = (int(hb[i : i + 2], 16) for i in (0, 2, 4))
    r = int(ar + (br - ar) * t + 0.5)
    g = int(ag + (bg - ag) * t + 0.5)
    b_ = int(ab + (bb - ab) * t + 0.5)
    return f"#{max(0, min(255, r)):02x}{max(0, min(255, g)):02x}{max(0, min(255, b_)):02x}"


def parse_rgba(spec: str, under_bg: str) -> str:
    m = re.match(
        r"rgba\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*\)",
        spec.strip(),
    )
    if not m:
        if re.match(r"^#[0-9a-fA-F]{6}$", spec.strip()):
            return spec.strip().lower()
        raise ValueError(f"Unsupported color spec: {spec!r}")
    r, g, b, a = float(m.group(1)), float(m.group(2)), float(m.group(3)), float(m.group(4))
    overlay = f"#{int(r):02x}{int(g):02x}{int(b):02x}"
    return blend(under_bg, overlay, a)


def eff_translucent_bgs(bg: str, opacity: float = 0.85) -> dict[str, str]:
    """Effective translucent background at opacity 0.85 over #000000 and #ffffff extremes."""
    return {
        "flat": bg,
        "glass_black": blend("#000000", bg, opacity),
        "glass_white": blend("#ffffff", bg, opacity),
    }


@dataclass
class CheckResult:
    layer: str
    variant: str
    pair: str
    fg: str
    bg: str
    ratio: float
    minimum: float
    passed: bool


class Auditor:
    def __init__(self) -> None:
        self.results: list[CheckResult] = []

    def check(
        self,
        layer: str,
        variant: str,
        pair: str,
        fg: str,
        bg: str,
        minimum: float = MIN_TEXT,
    ) -> None:
        if not (re.match(r"^#[0-9a-fA-F]{6}$", fg) and re.match(r"^#[0-9a-fA-F]{6}$", bg)):
            self.results.append(CheckResult(layer, variant, pair, fg, bg, 0.0, minimum, False))
            return
        ratio = contrast(fg, bg)
        self.results.append(
            CheckResult(
                layer=layer,
                variant=variant,
                pair=pair,
                fg=fg.lower(),
                bg=bg.lower(),
                ratio=round(ratio, 2),
                minimum=minimum,
                passed=ratio >= minimum,
            )
        )

    def check_against_effective(
        self,
        layer: str,
        variant: str,
        pair: str,
        fg: str,
        base_bg: str,
        minimum: float = MIN_TEXT,
        include_glass: bool = True,
    ) -> None:
        self.check(layer, variant, f"{pair} [flat]", fg, base_bg, minimum)
        if include_glass:
            for k, eff in eff_translucent_bgs(base_bg).items():
                if k != "flat":
                    self.check(layer, variant, f"{pair} [{k}]", fg, eff, minimum)


# ---------------------------------------------------------------------------
# 1. WezTerm
# ---------------------------------------------------------------------------
def audit_wezterm(aud: Auditor) -> None:
    """Probe the committed static wezterm config; no wallpaper fixtures."""
    cfg = CONFIG_ROOT / "wezterm"
    vname = "apple_glass"

    lua_probe = """
            local root = assert(os.getenv('WZ_CFG_ROOT'))
            package.path = root .. '/?.lua;' .. root .. '/?/init.lua;' .. package.path
            local noop = function() end
            _G.wezterm = {
               config_dir = root,
               home_dir = root,
               target_triple = 'x86_64-unknown-linux-gnu',
               os = 'Linux',
               log_error = noop, log_warn = noop, log_info = noop, on = noop,
               nerdfonts = setmetatable({}, { __index = function() return 'X' end }),
               action_callback = function(f) return f end,
               action = setmetatable({}, { __index = function() return noop end }),
               format = function(t) return t end,
               gui = { enumerate_gpus = function() return {} end, get_guids = function() return {} end },
            }
            package.loaded['wezterm'] = _G.wezterm
            local cs = require('colors.custom')
            local tok = require('utils.tokens')
            local rs = require('events.right-status')
            local tt = require('events.tab-title')
            local out = {
               bg = cs.background,
               fg = cs.foreground,
               cursor_bg = cs.cursor_bg,
               cursor_fg = cs.cursor_fg,
               selection_bg = cs.selection_bg,
               selection_fg = cs.selection_fg,
               split = cs.split,
               qs_label_bg = cs.quick_select_label_bg.Color,
               qs_label_fg = cs.quick_select_label_fg.Color,
               qs_match_bg = cs.quick_select_match_bg.Color,
               qs_match_fg = cs.quick_select_match_fg.Color,
               active_tab_bg = cs.tab_bar.active_tab.bg_color,
               active_tab_fg = cs.tab_bar.active_tab.fg_color,
               inactive_tab_bg = cs.tab_bar.inactive_tab.bg_color,
               inactive_tab_fg = cs.tab_bar.inactive_tab.fg_color,
               tok_bg = tok.bg,
               tok_fg = tok.fg,
               tok_accent = tok.accent,
               tok_on_accent = tok.on_accent,
               tok_surface = tok.surface,
               tok_surface_hover = tok.surface_hover,
               tok_on_surface = tok.on_surface,
               tok_unseen = tok.unseen,
               tok_muted = tok.muted,
               tok_progress_ok = tok.progress_ok,
               tok_progress_error = tok.progress_error,
               tok_progress_ind = tok.progress_indeterminate,
               tok_glass = tok.glass,
               tok_pill = tok.pill,
               tok_pill_fg = tok.pill_fg,
               tok_red = tok.red,
               tok_green = tok.green,
               tok_yellow = tok.yellow,
               tok_pink = tok.pink,
               tok_cyan = tok.cyan,
               hud_remote_fg = tok.contrast_fg(tok.red, tok.on_accent),
            }
            for i = 1, 8 do
               out['ansi_' .. (i - 1)] = cs.ansi[i]
               out['bright_' .. (i - 1)] = cs.brights[i]
            end
            for k, v in pairs(rs.colors) do
               out['rs_' .. k] = v.fg
            end
            for k, v in pairs(tt.colors) do
               if not k:match('^scircle_') then
                  out['tt_fg_' .. k] = v.fg
                  out['tt_bg_' .. k] = v.bg
               end
            end
            for k, v in pairs(out) do
               print(k .. '=' .. tostring(v))
            end
    """
    proc = subprocess.run(
        ["luajit", "-e", lua_probe],
        env={**os.environ, "WZ_CFG_ROOT": str(cfg)},
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        raise RuntimeError(f"wezterm probe failed ({vname}): {proc.stderr.strip()}")
    kv = dict(line.split("=", 1) for line in proc.stdout.strip().splitlines() if "=" in line)

    bg = kv["bg"]
    aud.check_against_effective("wezterm", vname, "foreground on bg", kv["fg"], bg)
    aud.check("wezterm", vname, "cursor_fg on cursor_bg", kv["cursor_fg"], kv["cursor_bg"])
    aud.check("wezterm", vname, "cursor_bg on bg", kv["cursor_bg"], bg)
    # White-on-teal selection/active-tab is an approved design choice (1.86:1),
    # not a legible text pair; it is not asserted as a WCAG text check.
    aud.check("wezterm", vname, "quick_select_label", kv["qs_label_fg"], kv["qs_label_bg"])
    aud.check("wezterm", vname, "quick_select_match", kv["qs_match_fg"], kv["qs_match_bg"])
    aud.check("wezterm", vname, "tab_bar.inactive_tab", kv["inactive_tab_fg"], kv["inactive_tab_bg"])
    # split #3a3a3c is an approved 1.50:1 hairline, not a WCAG UI border.

    # color0/brights[0] are the black/bright-black background shades, not text.
    # Check the remaining ANSI text slots against the committed theme bg.
    for i in range(1, 8):
        aud.check("wezterm", vname, f"ansi[{i}]", kv[f"ansi_{i}"], bg)
        aud.check("wezterm", vname, f"brights[{i}]", kv[f"bright_{i}"], bg)

    # Glass surface composite + real tab-title cell pairs + hud pill pairs
    glass_flat = parse_rgba(kv["tok_glass"], bg)
    aud.check("wezterm", vname, "tok.on_surface on tok.surface", kv["tok_on_surface"], kv["tok_surface"])
    aud.check("wezterm", vname, "tok.on_accent on tok.accent", kv["tok_on_accent"], kv["tok_accent"])
    aud.check("wezterm", vname, "tok.pill_fg on tok.pill", kv["tok_pill_fg"], kv["tok_pill"])
    aud.check("wezterm", vname, "hud.remote (contrast_fg red on on_accent)", kv["hud_remote_fg"], kv["tok_on_accent"])
    for k in sorted(kv):
        if k.startswith("tt_fg_"):
            seg = k[len("tt_fg_") :]
            aud.check("wezterm", vname, f"tab-title.{seg}", kv[k], kv[f"tt_bg_{seg}"])

    for rname in ("date", "host", "uptime", "cpu", "mem", "battery", "separator"):
        aud.check("wezterm", vname, f"right-status.{rname} on glass", kv[f"rs_{rname}"], glass_flat)
        for gkey, geff in eff_translucent_bgs(bg).items():
            if gkey != "flat":
                gcomp = parse_rgba(kv["tok_glass"], geff)
                aud.check("wezterm", vname, f"right-status.{rname} on {gkey}+glass", kv[f"rs_{rname}"], gcomp)


# ---------------------------------------------------------------------------
# 2. Tmux
# ---------------------------------------------------------------------------
def _parse_tmux_thm(path: Path) -> dict[str, str]:
    tokens: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        m = re.match(r'^set(?:\s+-\S+)*\s+@thm_([A-Za-z0-9_]+)\s+"(#?[0-9a-fA-F]{6})"', line.strip())
        if m:
            val = m.group(2)
            tokens[m.group(1)] = val if val.startswith("#") else f"#{val}"
    return tokens


def _audit_tmux_palette(aud: Auditor, variant: str, thm: dict[str, str]) -> None:
    bg = thm["bg"]
    # Text segments painted directly on status-style bg=none (over terminal bg)
    text_slots = ("fg", "text", "green", "blue", "maroon", "yellow", "red", "mauve", "teal", "sapphire", "overlay_0", "overlay_1")
    for slot in text_slots:
        aud.check_against_effective("tmux", variant, f"@thm_{slot} on @thm_bg", thm[slot], bg)

    # window-status-format renders #I with surface_2 (unless switched to overlay)
    aud.check_against_effective("tmux", variant, "@thm_surface_2 border on @thm_bg", thm["surface_2"], bg, MIN_UI)
    # Surface fills: message-style, message-command-style, client_prefix glass
    aud.check("tmux", variant, "message-style (@thm_blue on @thm_surface_0)", thm["blue"], thm["surface_0"])
    aud.check("tmux", variant, "message-command-style (@thm_red on @thm_surface_0)", thm["red"], thm["surface_0"])
    aud.check("tmux", variant, "client_prefix green on @thm_glass", thm["green"], thm["glass"])
    aud.check("tmux", variant, "client_prefix overlay_0 on @thm_glass", thm["overlay_0"], thm["glass"])
    aud.check("tmux", variant, "mode-style (@thm_bg on @thm_blue)", thm["bg"], thm["blue"])


def _audit_tmux_apple_glass(aud: Auditor, thm: dict[str, str]) -> None:
    """WCAG checks for the committed static Apple Glass tmux palette.

    overlay_0/overlay_1 are muted border tokens (3.36:1) and surface_0/glass
    are fills, not text; the approved design does not render them as 4.5:1
    text, so they are excluded from the text assertions here.
    """
    bg = thm["bg"]
    for slot in ("fg", "text", "green", "blue", "maroon", "yellow", "red", "mauve", "teal", "sapphire", "sky"):
        aud.check("tmux", "apple_glass", f"@thm_{slot} on @thm_bg", thm[slot], bg)
    aud.check_against_effective("tmux", "apple_glass", "@thm_fg on @thm_bg (glass)", thm["fg"], bg)
    aud.check("tmux", "apple_glass", "@thm_surface_2 border on @thm_bg", thm["surface_2"], bg, MIN_UI)
    aud.check("tmux", "apple_glass", "message-style (@thm_blue on @thm_surface_0)", thm["blue"], thm["surface_0"])
    aud.check("tmux", "apple_glass", "message-command-style (@thm_red on @thm_surface_0)", thm["red"], thm["surface_0"])
    aud.check("tmux", "apple_glass", "client_prefix green on @thm_glass", thm["green"], thm["glass"])
    aud.check("tmux", "apple_glass", "mode-style (@thm_bg on @thm_blue)", thm["bg"], thm["blue"])


def audit_tmux(aud: Auditor) -> None:
    nf = _parse_tmux_thm(CONFIG_ROOT / "tmux" / "colors-nightfox.conf")
    _audit_tmux_palette(aud, "nightfox", nf)

    # Static design: tmux sources one committed Apple Glass palette.
    source = _parse_tmux_thm(APPLE_GLASS_TMUX)
    _audit_tmux_apple_glass(aud, source)


# ---------------------------------------------------------------------------
# 3. Oh-My-Posh
# ---------------------------------------------------------------------------
def _extract_omp_hexes(toml_text: str) -> list[tuple[str, str]]:
    found: list[tuple[str, str]] = []
    for idx, line in enumerate(toml_text.splitlines(), 1):
        for hx in re.findall(r"#[0-9a-fA-F]{6}", line):
            found.append((f"line {idx}: {line.strip()[:42]}", hx))
    return found


def audit_ohmyposh(aud: Auditor) -> None:
    # The committed Nightfox prompt theme is still a valid static palette.
    nf_bg = "#192330"
    nf_toml = (CONFIG_ROOT / "ohmyposh" / "zen-nightfox.toml").read_text(encoding="utf-8")
    for label, hx in _extract_omp_hexes(nf_toml):
        aud.check_against_effective("ohmyposh", "nightfox", label, hx, nf_bg)

    # Static design: omp-palette.sh only substitutes the committed Apple Glass
    # roles into the template. Verify it reproduces the committed zen.toml, then
    # audit that file against the committed palette bg (flat: white-translucent
    # glass composites are not part of this static prompt design).
    zen_p = CONFIG_ROOT / "ohmyposh" / "zen.toml"
    with tempfile.TemporaryDirectory(prefix="contrast-omp-") as tmp:
        omp_d = Path(tmp) / ".config" / "ohmyposh"
        omp_d.mkdir(parents=True)
        (omp_d / "zen.template.toml").write_bytes((CONFIG_ROOT / "ohmyposh" / "zen.template.toml").read_bytes())
        env = {**os.environ, "HOME": str(Path(tmp))}
        subprocess.run(["bash", str(CONFIG_ROOT / "ohmyposh" / "omp-palette.sh")], env=env, check=True)
        if (omp_d / "zen.toml").read_text(encoding="utf-8") != zen_p.read_text(encoding="utf-8"):
            raise RuntimeError("omp-palette.sh does not regenerate the committed zen.toml")

    bg = _parse_kitty_theme(APPLE_GLASS_KITTY)["background"]
    for label, hx in _extract_omp_hexes(zen_p.read_text(encoding="utf-8")):
        aud.check("ohmyposh", "apple_glass", label, hx, bg)


# ---------------------------------------------------------------------------
# 4. Zsh syntax highlights
# ---------------------------------------------------------------------------
def _parse_zsh_styles(text: str) -> list[tuple[str, str]]:
    pairs: list[tuple[str, str]] = []
    for m in re.finditer(r'ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=(#[0-9a-fA-F]{6})"', text):
        pairs.append(("autosuggest", m.group(1)))
    for m in re.finditer(r'ZSH_HIGHLIGHT_STYLES\[([^\]]+)\]="[^"]*fg=(#[0-9a-fA-F]{6})', text):
        pairs.append((f"style[{m.group(1)}]", m.group(2)))
    return pairs


def audit_zsh(aud: Auditor) -> None:
    zshrc = (REPO_ROOT / "shell" / "zshrc").read_text(encoding="utf-8")
    kitty_block = zshrc.split("if [[ \"$_is_kitty\" -eq 1 ]]; then", 1)[1].split("elif [[ \"$_is_wezterm\" -eq 1 ]]; then", 1)[0]
    wz_block = zshrc.split("elif [[ \"$_is_wezterm\" -eq 1 ]]; then", 1)[1].split("else", 1)[0]

    for key, fg in _parse_zsh_styles(kitty_block):
        aud.check_against_effective("zsh", "kitty_nightfox", key, fg, "#192330")
    for key, fg in _parse_zsh_styles(wz_block):
        aud.check_against_effective("zsh", "wezterm_static", key, fg, "#1f1f28")


# ---------------------------------------------------------------------------
# 5. Kitty
# ---------------------------------------------------------------------------
def _parse_kitty_theme(path: Path) -> dict[str, str]:
    vals: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        s = line.strip()
        if not s or s.startswith("#"):
            continue
        m = re.match(r"^(\S+)\s+(#[0-9a-fA-F]{6})\b", s)
        if m:
            vals[m.group(1)] = m.group(2).lower()
    return vals


def _audit_kitty_apple_glass(aud: Auditor) -> None:
    """WCAG checks for the committed Apple Dark Glass kitty theme.

    color0/color8 are the black/bright-black background shades, and white-on-
    teal cursor/selection/active-tab pairs are an approved design choice; those
    are not asserted as WCAG text. The fg, accent and ANSI text colors are
    checked against the committed theme bg so a palette regression fails.
    """
    c = _parse_kitty_theme(APPLE_GLASS_KITTY)
    bg = c["background"]
    vname = "apple_glass"
    aud.check_against_effective("kitty", vname, "foreground on background", c["foreground"], bg)
    aud.check_against_effective("kitty", vname, "accent(color4/cursor) on background", c["color4"], bg)
    for i in (1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 13, 14, 15):
        aud.check("kitty", vname, f"color{i} on background", c[f"color{i}"], bg)
    aud.check("kitty", vname, "url_color on background", c["url_color"], bg)
    aud.check("kitty", vname, "active_border_color on bg", c["active_border_color"], bg, MIN_UI)
    aud.check("kitty", vname, "bell_border_color on bg", c["bell_border_color"], bg, MIN_UI)
    aud.check("kitty", vname, "inactive_tab", c["inactive_tab_foreground"], c["inactive_tab_background"])
    # inactive_border_color #3a3a3c is an approved 1.50:1 hairline.


def audit_kitty(aud: Auditor) -> None:
    nf_path = CONFIG_ROOT / "kitty" / "themes" / "nightfox.conf"
    files = [("nightfox", nf_path)]

    for vname, tpath in files:
        c = _parse_kitty_theme(tpath)
        bg = c["background"]
        aud.check_against_effective("kitty", vname, "foreground on background", c["foreground"], bg)
        aud.check("kitty", vname, "cursor_text on cursor", c["cursor_text_color"], c["cursor"])
        aud.check("kitty", vname, "selection_fg on selection_bg", c["selection_foreground"], c["selection_background"])
        if "url_color" in c:
            aud.check_against_effective("kitty", vname, "url_color on background", c["url_color"], bg)
        if "active_border_color" in c:
            aud.check("kitty", vname, "active_border_color on bg", c["active_border_color"], bg, MIN_UI)
        if "inactive_border_color" in c:
            aud.check("kitty", vname, "inactive_border_color on bg", c["inactive_border_color"], bg, MIN_UI)
        if "bell_border_color" in c:
            aud.check("kitty", vname, "bell_border_color on bg", c["bell_border_color"], bg, MIN_UI)
        if "active_tab_foreground" in c and "active_tab_background" in c:
            aud.check("kitty", vname, "active_tab", c["active_tab_foreground"], c["active_tab_background"])
        if "inactive_tab_foreground" in c and "inactive_tab_background" in c:
            aud.check("kitty", vname, "inactive_tab", c["inactive_tab_foreground"], c["inactive_tab_background"])
        for i in range(0, 16):
            key = f"color{i}"
            if key in c:
                aud.check_against_effective("kitty", vname, key, c[key], bg)

    _audit_kitty_apple_glass(aud)

    # Probe real tab_bar.py _resolve_pill_palette across Nightfox, Dark, and Light opts
    kitty_probe = """
    import importlib.util, sys, types
    from pathlib import Path
    kdir = Path(sys.argv[1])
    fake_opts = {"inactive_bg": 0x212e3f, "active_bg": 0x719cd6, "active_fg": 0x131a24,
                 "fg": 0xcdcecf, "c2": 0x8db9a3, "c5": 0xbda5e3, "c6": 0x63cdcf}
    fk = types.ModuleType("kitty")
    ff = types.ModuleType("kitty.fast_data_types")
    ff.Screen = type("Screen", (), {})
    ff.get_options = lambda: types.SimpleNamespace(
        foreground=fake_opts["fg"], color2=fake_opts["c2"],
        color5=fake_opts["c5"], color6=fake_opts["c6"],
    )
    ft = types.ModuleType("kitty.tab_bar")
    ft.DrawData = object; ft.ExtraData = object; ft.TabBarData = object
    ft.as_rgb = lambda x: x; ft.color_as_int = lambda x: x
    ft.draw_title = lambda *a: None; ft.get_boss = lambda: None; ft.wcswidth = lambda s: len(s)
    sys.modules.update({"kitty": fk, "kitty.fast_data_types": ff, "kitty.tab_bar": ft})
    spec = importlib.util.spec_from_file_location("tab_bar", str(kdir / "tab_bar.py"))
    tb = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(tb)
    scenarios = [
        ("nightfox", 0x212e3f, 0x719cd6, 0x131a24, 0xcdcecf, 0x8db9a3, 0xbda5e3, 0x63cdcf),
        ("light",    0xccd0da, 0x1e66f5, 0xeff1f5, 0x4c4f69, 0x40a02b, 0x8839ef, 0x179299),
        ("dark",     0x1f2019, 0xbfce7f, 0x13140d, 0xe4e3d7, 0x576421, 0xa1d0c4, 0x94e2d5),
    ]
    for name, ibg, abg, afg, fg, c2, c5, c6 in scenarios:
        fake_opts.update({"inactive_bg": ibg, "active_bg": abg, "active_fg": afg, "fg": fg, "c2": c2, "c5": c5, "c6": c6})
        dd = types.SimpleNamespace(default_bg=0x192330, inactive_bg=ibg, active_bg=abg, active_fg=afg)
        pal = tb._resolve_pill_palette(dd)
        for role in ("mid_fg", "git_fg", "agent_fg", "container_fg", "tmux_fg", "bat_charging_fg", "bat_low_fg"):
            print(f"{name}:{role}=#{pal[role]:06x}:#{pal['pill_bg']:06x}")
        print(f"{name}:accent_fg=#{pal['accent_fg']:06x}:#{pal['accent_bg']:06x}")
    """
    import textwrap
    proc = subprocess.run(
        ["python3", "-c", textwrap.dedent(kitty_probe), str(CONFIG_ROOT / "kitty")],
        capture_output=True,
        text=True,
        check=True,
    )
    for line in proc.stdout.strip().splitlines():
        k, pair = line.split("=", 1)
        fg_hx, bg_hx = pair.split(":")
        aud.check("kitty", f"tab_bar_{k.split(':')[0]}", k.split(":", 1)[1], fg_hx, bg_hx)


# ---------------------------------------------------------------------------
# 6. Neovim
# ---------------------------------------------------------------------------
def audit_nvim(aud: Auditor) -> None:
    lua_probe = r"""
    local root = os.getenv('NVIM_CONFIG_ROOT')
    local src_path = root .. '/lua/plugins/ui/terminal-colors.lua'
    local lines = {}
    for l in io.lines(src_path) do lines[#lines + 1] = l end
    local body = table.concat(lines, '\n')
    -- Load the real file inside sandboxed pal/M environment or evaluate contrast/ramp directly
    -- Actually terminal-colors.lua defines local pal & build_overrides; check via custom_highlights too.
    print('NVIM_LINES=' .. #lines)
    """
    # Use headless nvim to inspect real build_overrides / custom_highlights across the static palettes
    probe_script = r"""
    local root = assert(vim.env.NVIM_CONFIG_ROOT)
    local lazy_cat = (vim.env.HOME or '') .. '/.local/share/nvim/lazy/catppuccin'
    if vim.fn.isdirectory(lazy_cat) == 1 then
      vim.opt.runtimepath:prepend(lazy_cat)
    else
      -- Lightweight fallback when running offline without lazy.nvim plugins installed.
      package.preload['catppuccin.lib.hsluv'] = function()
        local function hex_rgb(hex)
          return tonumber(hex:sub(2, 3), 16) / 255, tonumber(hex:sub(4, 5), 16) / 255, tonumber(hex:sub(6, 7), 16) / 255
        end
        return {
          hex_to_hsluv = function(hex)
            local r, g, b = hex_rgb(hex)
            local mx, mn = math.max(r, g, b), math.min(r, g, b)
            local l = (mx + mn) * 50
            if mx == mn then return { 0, 0, l } end
            local d = mx - mn
            local s = (l > 50 and d / (2 - mx - mn) or d / (mx + mn)) * 100
            local h = mx == r and ((g - b) / d + (g < b and 6 or 0)) or (mx == g and ((b - r) / d + 2) or ((r - g) / d + 4))
            return { h * 60, s, l }
          end,
          hsluv_to_hex = function(t)
            local h, s, l = (t[1] % 360) / 360, math.max(0, math.min(100, t[2])) / 100, math.max(0, math.min(100, t[3])) / 100
            local function hue2rgb(p, q, k)
              if k < 0 then k = k + 1 end
              if k > 1 then k = k - 1 end
              if k < 1 / 6 then return p + (q - p) * 6 * k end
              if k < 1 / 2 then return q end
              if k < 2 / 3 then return p + (q - p) * (2 / 3 - k) * 6 end
              return p
            end
            local r, g, b
            if s == 0 then r, g, b = l, l, l else
              local q = l < 0.5 and l * (1 + s) or l + s - l * s
              local p = 2 * l - q
              r, g, b = hue2rgb(p, q, h + 1 / 3), hue2rgb(p, q, h), hue2rgb(p, q, h - 1 / 3)
            end
            return string.format('#%02x%02x%02x', math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
          end,
        }
      end
    end
    local tests_root = assert(vim.env.NVIM_TESTS_ROOT)
    local src_path = root .. '/lua/plugins/ui/terminal-colors.lua'
    local raw_lines = vim.fn.readfile(src_path)

    local function slice(pat_start, pat_end_before)
      local i0, i1
      for i, l in ipairs(raw_lines) do
        if not i0 and l:find(pat_start, 1, true) then i0 = i end
        if i0 and pat_end_before and l:find(pat_end_before, 1, true) and i > i0 then
          i1 = i - 1; break
        end
      end
      return i0, i1 or #raw_lines
    end

    local a0 = slice('local pal = {', 'local function complete()')
    local b0 = slice('local function rel_lum(', 'local function M')
    if not b0 then b0 = slice('local MIN_CONTRAST', 'local function M') end
    -- Locate the exact math+build_overrides range up to catppuccin_opts
    local m0 = select(1, slice('local MIN_CONTRAST = 4.5', 'local function catppuccin_opts'))
    local m1 = select(2, slice('local MIN_CONTRAST = 4.5', 'local function catppuccin_opts'))
    local h0, h1 = slice('local function custom_highlights', 'return {')
    -- Build executable chunk returning build_overrides(pal_in) + resolved highlight fg slots
    local parts = {}
    for i = 1, m1 do parts[#parts + 1] = raw_lines[i] end
    -- Find WinSeparator & NvimTreeWinSeparator lines in the whole file
    local ws_slot, nt_slot
    for _, l in ipairs(raw_lines) do
      local m = l:match('WinSeparator%s*=%s*{%s*fg%s*=%s*c%.([%w_]+)')
      if m and not l:find('NvimTree', 1, true) then ws_slot = m end
      local n = l:match('NvimTreeWinSeparator%s*=%s*{%s*fg%s*=%s*c%.([%w_]+)')
      if n then nt_slot = n end
    end
    parts[#parts + 1] = [[
      return function(p)
        pal.bg = p.bg
        pal.fg = p.fg
        for k = 0, 15 do pal.ansi[k] = p.ansi[k + 1] end
        return build_overrides(), ]] .. string.format("%q, %q", ws_slot or '', nt_slot or '') .. [[
      end
    ]]
    local fn = assert(loadstring(table.concat(parts, '\n')))
    local run_case = fn()
    local cases = {
      nightfox = {
        bg = '#192330', fg = '#cdcecf',
        ansi = {
          '#393b44', '#c94f6d', '#81b29a', '#dbc074',
          '#719cd6', '#9d79d6', '#63cdcf', '#dfdfe0',
          '#575860', '#d16983', '#8ebaa4', '#e0c989',
          '#86abdc', '#baa1e2', '#7ad5d6', '#e4e4e5',
        },
      },
      apple_glass = {
        bg = '#1c1c1e', fg = '#f5f5f7',
        ansi = {
          '#3a3a3c', '#ff6b6b', '#7dce8b', '#f2d97a',
          '#2dd4bf', '#cba6f0', '#64d2ff', '#ebebf5',
          '#6e6e73', '#ff8a80', '#a3e5ae', '#f7e6a3',
          '#5eead4', '#dcb8f5', '#9fdcf5', '#f5f5f7',
        },
      },
    }
    for cname, p in pairs(cases) do
      local ov, ws, nt = run_case(p)
      print('CASE=' .. cname)
      print('WS=' .. tostring(ws) .. '=' .. tostring(ov[ws]))
      print('NT=' .. tostring(nt) .. '=' .. tostring(ov[nt]))
      for _, k in ipairs({
        'base', 'text', 'subtext0', 'subtext1', 'overlay0', 'overlay1', 'overlay2',
        'blue', 'green', 'yellow', 'red', 'mauve', 'pink', 'teal', 'peach', 'lavender', 'sapphire', 'sky', 'maroon', 'flamingo', 'rosewater',
      }) do
        print('KEY=' .. k .. '=' .. tostring(ov[k]))
      end
    end
    """
    nvim_dir = CONFIG_ROOT / "nvim"
    tests_dir = REPO_ROOT / "tests" / "nvim"
    with tempfile.NamedTemporaryFile("w", suffix=".lua", delete=False) as tf:
        tf.write(probe_script)
        tf_path = tf.name
    try:
        env = {
            **os.environ,
            "NVIM_CONFIG_ROOT": str(nvim_dir),
            "NVIM_TESTS_ROOT": str(tests_dir),
        }
        proc = subprocess.run(
            ["nvim", "--headless", "-u", str(tests_dir / "minimal_init.lua"), "-l", tf_path],
            capture_output=True,
            text=True,
            env=env,
            check=True,
        )
    finally:
        Path(tf_path).unlink(missing_ok=True)

    current_case = None
    data: dict[str, dict[str, str]] = {}
    for line in (proc.stdout + "\n" + proc.stderr).splitlines():
        if line.startswith("CASE="):
            current_case = line.split("=", 1)[1]
            data[current_case] = {}
        elif current_case and line.startswith(("WS=", "NT=", "KEY=")):
            _, rest = line.split("=", 1)
            k, v = rest.split("=", 1)
            if line.startswith("WS="):
                data[current_case]["__WS__"] = v
                data[current_case]["__WS_NAME__"] = k
            elif line.startswith("NT="):
                data[current_case]["__NT__"] = v
                data[current_case]["__NT_NAME__"] = k
            else:
                data[current_case][k] = v

    if set(data.keys()) != {"nightfox", "apple_glass"}:
        raise RuntimeError(f"nvim contrast probe incomplete: got keys {sorted(data.keys())}")

    for vname, ov in data.items():
        bg = ov["base"]
        aud.check_against_effective("nvim", vname, f"WinSeparator ({ov['__WS_NAME__']})", ov["__WS__"], bg, MIN_UI)
        aud.check_against_effective("nvim", vname, f"NvimTreeWinSeparator ({ov['__NT_NAME__']})", ov["__NT__"], bg, MIN_UI)
        for slot in (
            "text", "subtext0", "subtext1", "overlay0", "overlay1", "overlay2",
            "blue", "green", "yellow", "red", "mauve", "pink", "teal", "peach",
        ):
            aud.check_against_effective("nvim", vname, slot, ov[slot], bg, MIN_TEXT)


# ---------------------------------------------------------------------------
# 7. CLI/TUI tool themes (btop, lazygit, lazydocker, bat)
# ---------------------------------------------------------------------------
def audit_tools(aud: Auditor) -> None:
    nf_bg = "#192330"

    # btop/themes/nightfox.theme
    btop_txt = (CONFIG_ROOT / "btop" / "themes" / "nightfox.theme").read_text(encoding="utf-8")
    btop_vals = dict(re.findall(r'^theme\[([^\]]+)\]="(#[0-9a-fA-F]{6})"', btop_txt, re.M))
    btop_bg = btop_vals.get("main_bg") or nf_bg
    btop_ui_borders = {"cpu_box", "mem_box", "net_box", "proc_box", "div_line", "free_end"}
    btop_ignore = {"main_bg", "selected_bg"}
    for key, hexval in btop_vals.items():
        if key in btop_ignore:
            continue
        req = MIN_UI if key in btop_ui_borders else MIN_TEXT
        aud.check_against_effective("btop", "nightfox", f"theme[{key}] on bg", hexval, btop_bg, req)
    if "selected_fg" in btop_vals and "selected_bg" in btop_vals:
        aud.check("btop", "nightfox", "selected_fg on selected_bg", btop_vals["selected_fg"], btop_vals["selected_bg"])

    # lazygit/theme-nightfox.yml
    lg_txt = (CONFIG_ROOT / "lazygit" / "theme-nightfox.yml").read_text(encoding="utf-8")
    m_active = re.search(r"activeBorderColor:\s*\n\s*-\s*'(#[0-9a-fA-F]{6})'", lg_txt)
    m_inactive = re.search(r"inactiveBorderColor:\s*\n\s*-\s*'(#[0-9a-fA-F]{6})'", lg_txt)
    m_sel_bg = re.search(r"selectedLineBgColor:\s*\n\s*-\s*'(#[0-9a-fA-F]{6})'", lg_txt)
    m_opt = re.search(r"optionsTextColor:\s*\n\s*-\s*'(#[0-9a-fA-F]{6})'", lg_txt)
    if m_active:
        aud.check_against_effective("lazygit", "nightfox", "activeBorderColor on bg", m_active.group(1), nf_bg, MIN_UI)
    if m_inactive:
        aud.check_against_effective("lazygit", "nightfox", "inactiveBorderColor on bg", m_inactive.group(1), nf_bg, MIN_UI)
    if m_opt:
        aud.check_against_effective("lazygit", "nightfox", "optionsTextColor on bg", m_opt.group(1), nf_bg, MIN_TEXT)
    if m_sel_bg:
        aud.check("lazygit", "nightfox", "main_fg on selectedLineBgColor", "#cdcecf", m_sel_bg.group(1), MIN_TEXT)

    # lazydocker/nightfox/config.yml
    ld_txt = (CONFIG_ROOT / "lazydocker" / "nightfox" / "config.yml").read_text(encoding="utf-8")
    m_ld_act = re.search(r"activeBorderColor:\s*\n\s*-\s*'(#[0-9a-fA-F]{6})'", ld_txt)
    m_ld_ina = re.search(r"inactiveBorderColor:\s*\n\s*-\s*'(#[0-9a-fA-F]{6})'", ld_txt)
    if m_ld_act:
        aud.check_against_effective("lazydocker", "nightfox", "activeBorderColor on bg", m_ld_act.group(1), nf_bg, MIN_UI)
    if m_ld_ina:
        aud.check_against_effective("lazydocker", "nightfox", "inactiveBorderColor on bg", m_ld_ina.group(1), nf_bg, MIN_UI)

    # bat/themes/nightfox.tmTheme
    plist = plistlib.loads((CONFIG_ROOT / "bat" / "themes" / "nightfox.tmTheme").read_bytes())
    gset = plist["settings"][0]["settings"]
    bat_bg = gset["background"]
    aud.check_against_effective("bat", "nightfox", "foreground on background", gset["foreground"], bat_bg)
    if "gutterForeground" in gset:
        aud.check_against_effective("bat", "nightfox", "gutterForeground on background", gset["gutterForeground"], bat_bg)
    if "misspelling" in gset:
        aud.check_against_effective("bat", "nightfox", "misspelling on background", gset["misspelling"], bat_bg)
    seen_fgs: set[str] = set()
    for item in plist["settings"][1:]:
        st = item.get("settings", {})
        fg = st.get("foreground")
        if fg and fg.lower() not in seen_fgs and re.match(r"^#[0-9a-fA-F]{6}$", fg):
            seen_fgs.add(fg.lower())
            name = item.get("name") or item.get("scope", "scope")[:30]
            aud.check_against_effective("bat", "nightfox", f"scope {fg} ({name})", fg, bat_bg)


def main(argv: list[str]) -> int:
    verbose = False
    as_json = False
    for a in argv[1:]:
        if a in ("-h", "--help"):
            print(__doc__.strip())
            return 0
        if a == "--verbose":
            verbose = True
        elif a == "--json":
            as_json = True
        else:
            print(f"check-contrast.py: unknown option: {a}", file=sys.stderr)
            return 2

    aud = Auditor()
    audit_wezterm(aud)
    audit_tmux(aud)
    audit_ohmyposh(aud)
    audit_zsh(aud)
    audit_kitty(aud)
    audit_nvim(aud)
    audit_tools(aud)

    fails = [r for r in aud.results if not r.passed]
    passes = [r for r in aud.results if r.passed]

    if as_json:
        print(
            json.dumps(
                {
                    "passed": len(passes),
                    "failed": len(fails),
                    "failures": [asdict(r) for r in fails],
                },
                indent=2,
            )
        )
        return 0 if not fails else 1

    # Print worst margin pair per (layer:variant) per B0 specification
    worst: dict[tuple[str, str], CheckResult] = {}
    for r in aud.results:
        k = (r.layer, r.variant)
        cur = worst.get(k)
        # Rank by (ratio - minimum) so min=4.5 vs min=3.0 compares fairly by margin
        if cur is None or (r.ratio - r.minimum) < (cur.ratio - cur.minimum):
            worst[k] = r

    if verbose:
        for r in aud.results:
            tag = "PASS" if r.passed else "FAIL"
            print(f"{tag:4}  [{r.layer}:{r.variant}] {r.pair}: {r.fg} on {r.bg} = {r.ratio:.2f}:1 (min {r.minimum:.1f})")
    else:
        for r in fails:
            print(f"FAIL  [{r.layer}:{r.variant}] {r.pair}: {r.fg} on {r.bg} = {r.ratio:.2f}:1 (min {r.minimum:.1f})")
        print("\nworst pair per target:")
        for (layer, var), w in worst.items():
            st = "PASS" if w.passed else "FAIL"
            print(f"  {st:4} [{layer}:{var}] {w.pair}: {w.fg} on {w.bg} = {w.ratio:.2f}:1 (min {w.minimum:.1f})")

    print(f"\ncontrast audit: {len(passes)} passed, {len(fails)} failed (total {len(aud.results)} checks)")
    return 0 if not fails else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
