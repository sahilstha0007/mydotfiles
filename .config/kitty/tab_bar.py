# =============================================================================
# Kitty Custom Tab Bar: Modern Floating Rounded Pills HUD
# Features:
#   - Floating rounded pill tabs ( ... ) harmonized with Nightfox palette
#   - Dynamic process badges ( nvim,  lazygit, 󰇥 yazi, 󰓅 btop,  tmux, 󰡨 docker, 󰚩 ai)
#   - Floating right-aligned status pills: Tmux, AI Agents, Containers, Git, CWD, Battery, Clock
#   - Adaptive width folding: gracefully drops breadcrumb/battery/containers on narrow screens
#   - Zero performance overhead: event-driven rendering + cached sysfs queries
# =============================================================================

import colorsys
import datetime
import glob
import os
import re
import shutil
import subprocess
import threading
import time
import unicodedata
from kitty.fast_data_types import Screen, get_options
from kitty.tab_bar import (
    DrawData,
    ExtraData,
    TabBarData,
    as_rgb,
    color_as_int,
    get_boss,
    wcswidth,
)

_POWER_SUPPLY_DIR = "/sys/class/power_supply"

# In-memory caches to eliminate redundant kernel/fs calls
_bat_lock = threading.Lock()
_bat_refreshing = False
_last_bat_query = 0.0
_cached_bat_str = ""
_cached_bat_fg = None
_cached_bat_raw = None

_BAT_CHARGING_RGB = 0xE0AF68
_BAT_LOW_RGB = 0xE0C989


def _chan_lum(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def _rel_lum_rgb(rgb_int: int) -> float:
    r = ((rgb_int >> 16) & 0xFF) / 255.0
    g = ((rgb_int >> 8) & 0xFF) / 255.0
    b = (rgb_int & 0xFF) / 255.0
    return 0.2126 * _chan_lum(r) + 0.7152 * _chan_lum(g) + 0.0722 * _chan_lum(b)


def _contrast_rgb(fg_int: int, bg_int: int) -> float:
    la, lb = _rel_lum_rgb(fg_int), _rel_lum_rgb(bg_int)
    hi, lo = (la, lb) if la >= lb else (lb, la)
    return (hi + 0.05) / (lo + 0.05)


def _ensure_contrast_rgb(fg_int: int, bg_int: int, min_ratio: float = 4.5) -> int:
    """Repair fg_int lightness away from bg_int until WCAG contrast >= min_ratio."""
    fg_int &= 0xFFFFFF
    bg_int &= 0xFFFFFF
    if _contrast_rgb(fg_int, bg_int) >= min_ratio:
        return fg_int
    r = ((fg_int >> 16) & 0xFF) / 255.0
    g = ((fg_int >> 8) & 0xFF) / 255.0
    b = (fg_int & 0xFF) / 255.0
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    target = 0.0 if _rel_lum_rgb(bg_int) >= 0.1791 else 1.0
    for step in range(1, 65):
        nr, ng, nb = colorsys.hls_to_rgb(h, l + (target - l) * step / 64.0, s)
        cand = (int(round(nr * 255)) << 16) | (int(round(ng * 255)) << 8) | int(round(nb * 255))
        if _contrast_rgb(cand, bg_int) >= min_ratio:
            return cand
    return 0x000000 if target == 0.0 else 0xFFFFFF

_last_git_query = 0.0
_last_git_cwd = ""
_cached_git_str = ""

_tmux_lock = threading.Lock()
_tmux_refreshing = False
_last_tmux_query = 0.0
_cached_tmux_str = ""

_agent_lock = threading.Lock()
_agent_refreshing = False
_last_agent_query = 0.0
_cached_agent_str = ""
_cached_tmux_agent_str = ""

_container_lock = threading.Lock()
_container_refreshing = False
_last_container_query = 0.0
_cached_container_str = ""


def _extract_exe_name(cmd0: str) -> str:
    """Extract normalized lowercase executable basename without trailing .exe."""
    exe = os.path.basename((cmd0 or "").strip()).lower()
    if exe.endswith(".exe"):
        exe = exe[:-4]
    return exe


def _refresh_battery() -> None:
    """Refresh battery status from sysfs ACPI asynchronously without blocking draw_tab."""
    global _last_bat_query, _cached_bat_str, _cached_bat_fg, _cached_bat_raw, _bat_refreshing
    bat_str = ""
    bat_fg = None
    bat_raw = None
    try:
        for bat_dir in sorted(glob.glob(os.path.join(_POWER_SUPPLY_DIR, "BAT*"))):
            try:
                cap_file = os.path.join(bat_dir, "capacity")
                stat_file = os.path.join(bat_dir, "status")
                if not os.path.exists(cap_file):
                    continue
                with open(cap_file, "r") as f:
                    cap = int(f.read().strip())
                stat = ""
                if os.path.exists(stat_file):
                    with open(stat_file, "r") as f:
                        stat = f.read().strip().lower()
                raw_fg = None
                if stat == "charging":
                    icon = "󰂄"
                    raw_fg = _BAT_CHARGING_RGB
                elif stat == "full" or cap >= 98:
                    continue
                elif cap >= 80:
                    icon = "󰁹"
                elif cap >= 50:
                    icon = "󰁿"
                elif cap >= 20:
                    icon = "󰁼"
                else:
                    icon = "󰁺"
                    raw_fg = _BAT_LOW_RGB
                bat_str = f"{icon} {cap}%"
                bat_fg = as_rgb(raw_fg) if raw_fg is not None else None
                bat_raw = raw_fg
                break
            except Exception:
                continue
    except Exception:
        pass
    finally:
        with _bat_lock:
            _cached_bat_str = bat_str
            _cached_bat_fg = bat_fg
            _cached_bat_raw = bat_raw
            _last_bat_query = time.monotonic()
            _bat_refreshing = False


def get_battery() -> tuple[str, int | None]:
    """Return cached battery label immediately; refresh sysfs in background on 20s TTL."""
    global _bat_refreshing
    now = time.monotonic()
    with _bat_lock:
        if _last_bat_query > 0.0 and now - _last_bat_query < 20.0:
            return _cached_bat_str, _cached_bat_fg
        if _bat_refreshing:
            return _cached_bat_str, _cached_bat_fg
        _bat_refreshing = True
        cached = (_cached_bat_str, _cached_bat_fg)
    try:
        threading.Thread(target=_refresh_battery, daemon=True).start()
    except Exception:
        with _bat_lock:
            _bat_refreshing = False
    return cached


def get_clock() -> str:
    return datetime.datetime.now().strftime("󰥔 %H:%M")


def get_active_cwd() -> str:
    cwd = None
    try:
        boss = get_boss()
        if boss:
            tab = boss.active_tab
            if tab and tab.active_window:
                cwd = tab.active_window.cwd_of_child
    except Exception:
        pass
    if not cwd:
        try:
            cwd = os.getcwd()
        except Exception:
            cwd = "~"
    return cwd


def format_breadcrumb(cwd: str) -> str:
    home = os.path.expanduser("~")
    if cwd == home:
        return " ~"
    if cwd.startswith(home):
        rel = cwd[len(home):].lstrip("/")
        parts = rel.split("/")
        if len(parts) <= 2:
            return " " + " › ".join(parts)
        return f" {parts[-2]} › {parts[-1]}"
    return f" {os.path.basename(cwd) or cwd}"


def get_git_info(cwd: str) -> str:
    global _last_git_query, _last_git_cwd, _cached_git_str
    now = time.monotonic()
    if _last_git_query > 0.0 and cwd == _last_git_cwd and now - _last_git_query < 3.0:
        return _cached_git_str
    _last_git_query = now
    _last_git_cwd = cwd
    try:
        git_dir = None
        cur = cwd
        for _ in range(4):
            candidate = os.path.join(cur, ".git")
            if os.path.exists(candidate):
                if os.path.isfile(candidate):
                    with open(candidate, "r") as f:
                        line = f.read().strip()
                        if line.startswith("gitdir:"):
                            git_dir = os.path.abspath(os.path.join(cur, line[7:].strip()))
                else:
                    git_dir = candidate
                break
            parent = os.path.dirname(cur)
            if parent == cur:
                break
            cur = parent

        if git_dir and os.path.exists(git_dir):
            head_path = os.path.join(git_dir, "HEAD")
            if os.path.exists(head_path):
                with open(head_path, "r") as f:
                    head = f.read().strip()
                if head.startswith("ref: refs/heads/"):
                    branch = head[16:]
                else:
                    branch = head[:7]
                if len(branch) > 16:
                    branch = branch[:15] + "…"
                _cached_git_str = f" {branch}"
                return _cached_git_str
    except Exception:
        pass
    _cached_git_str = ""
    return _cached_git_str


def _in_tmux_session() -> bool:
    """Return True when inside TMUX or the active Kitty window runs tmux (pure local check)."""
    if os.environ.get("TMUX"):
        return True
    try:
        boss = get_boss()
        if boss and boss.active_tab and boss.active_tab.active_window:
            child = boss.active_tab.active_window.child
            if child and child.foreground_processes:
                for p in child.foreground_processes:
                    cmdline = p.get("cmdline") or []
                    exe = _extract_exe_name(cmdline[0]) if cmdline else ""
                    if exe == "tmux" or exe.startswith("tmux:"):
                        return True
    except Exception:
        pass
    return False


def _refresh_tmux_session() -> None:
    """Refresh cached tmux session pill in background without blocking draw_tab."""
    global _last_tmux_query, _cached_tmux_str, _tmux_refreshing
    result = ""
    try:
        if shutil.which("tmux") is not None:
            res = subprocess.run(
                ["tmux", "display-message", "-p", "#S"],
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True,
                timeout=0.08,
            )
            name = res.stdout.strip() if getattr(res, "returncode", 0) == 0 else ""
            if name:
                result = f" {name}"
    except Exception:
        pass
    finally:
        with _tmux_lock:
            _cached_tmux_str = result
            _last_tmux_query = time.monotonic()
            _tmux_refreshing = False


def get_tmux_session() -> str:
    """Return cached tmux session pill immediately; refresh asynchronously on 5s TTL."""
    global _last_tmux_query, _cached_tmux_str, _tmux_refreshing
    now = time.monotonic()
    in_tmux = _in_tmux_session()
    with _tmux_lock:
        if not in_tmux:
            _cached_tmux_str = ""
            _last_tmux_query = now
            return ""
        if _last_tmux_query > 0.0 and now - _last_tmux_query < 5.0:
            return _cached_tmux_str
        if _tmux_refreshing:
            return _cached_tmux_str
        _tmux_refreshing = True
        cached = _cached_tmux_str
    try:
        threading.Thread(target=_refresh_tmux_session, daemon=True).start()
    except Exception:
        with _tmux_lock:
            _tmux_refreshing = False
    return cached


AGENT_NAMES = (
    "claude",
    "opencode",
    "cline",
    "codex",
    "copilot",
    "aider",
    "goose",
    "crush",
    "amp",
    "gemini",
    "herdr",
    "omni",
)
_AGENT_NAMES_SET = frozenset(AGENT_NAMES)


def _match_agent_name(cmd0: str) -> str | None:
    """Match an executable command against AGENT_NAMES by exact normalized basename."""
    exe = _extract_exe_name(cmd0)
    return exe if exe in _AGENT_NAMES_SET else None


def _format_agent_names(agent_names: set[str]) -> str:
    if not agent_names:
        return ""
    if len(agent_names) == 1:
        return f"󰚩 {next(iter(agent_names))}"
    return f"󰚩 {len(agent_names)} agents"


def _collect_boss_agents() -> set[str]:
    agent_names: set[str] = set()
    try:
        boss = get_boss()
        if boss:
            for tab in boss.all_tabs:
                for window in tab:
                    child = window.child
                    if child and child.foreground_processes:
                        for p in child.foreground_processes:
                            cmdline = p.get("cmdline") or []
                            matched = _match_agent_name(cmdline[0] if cmdline else "")
                            if matched:
                                agent_names.add(matched)
    except Exception:
        pass
    return agent_names


def _refresh_tmux_agents() -> None:
    global _last_agent_query, _cached_agent_str, _cached_tmux_agent_str, _agent_refreshing
    result = ""
    try:
        if shutil.which("tmux") is not None:
            res = subprocess.run(
                ["tmux", "list-panes", "-a", "-F", "#{pane_current_command}"],
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True,
                timeout=0.08,
            )
            if getattr(res, "returncode", 0) == 0:
                agent_names: set[str] = set()
                for line in res.stdout.strip().split("\n"):
                    matched = _match_agent_name(line)
                    if matched:
                        agent_names.add(matched)
                result = _format_agent_names(agent_names)
    except Exception:
        pass
    finally:
        with _agent_lock:
            _cached_tmux_agent_str = result
            _cached_agent_str = result
            _last_agent_query = time.monotonic()
            _agent_refreshing = False


def get_active_agents() -> str:
    global _last_agent_query, _cached_agent_str, _cached_tmux_agent_str, _agent_refreshing
    now = time.monotonic()
    with _agent_lock:
        if _last_agent_query > 0.0 and now - _last_agent_query < 5.0:
            return _cached_agent_str

    agent_names = _collect_boss_agents()
    if agent_names:
        result = _format_agent_names(agent_names)
        with _agent_lock:
            _cached_agent_str = result
            _last_agent_query = now
        return result

    if os.environ.get("TMUX_TMPDIR"):
        with _agent_lock:
            if _last_agent_query > 0.0 and now - _last_agent_query < 5.0:
                return _cached_agent_str
            if _agent_refreshing:
                return _cached_tmux_agent_str
            _agent_refreshing = True
            _cached_agent_str = _cached_tmux_agent_str
            cached = _cached_tmux_agent_str
        try:
            threading.Thread(target=_refresh_tmux_agents, daemon=True).start()
        except Exception:
            with _agent_lock:
                _agent_refreshing = False
        return cached

    with _agent_lock:
        _cached_agent_str = ""
        _cached_tmux_agent_str = ""
        _last_agent_query = now
        return _cached_agent_str


def _refresh_containers() -> None:
    global _last_container_query, _cached_container_str, _container_refreshing
    result = ""
    try:
        count = 0
        for runtime in ("podman", "docker"):
            if not shutil.which(runtime):
                continue
            res = subprocess.run(
                [runtime, "ps", "-q"],
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True,
                timeout=0.1,
            )
            if getattr(res, "returncode", 0) == 0:
                lines = [l for l in res.stdout.strip().split("\n") if l]
                count = len(lines)
                if count > 0:
                    break
        if count > 0:
            result = f"󰡨 {count}"
    except Exception:
        pass
    finally:
        with _container_lock:
            _cached_container_str = result
            _last_container_query = time.monotonic()
            _container_refreshing = False


def get_containers() -> str:
    global _last_container_query, _cached_container_str, _container_refreshing
    now = time.monotonic()
    with _container_lock:
        if _last_container_query > 0.0 and now - _last_container_query < 10.0:
            return _cached_container_str
        if _container_refreshing:
            return _cached_container_str
        _container_refreshing = True
        cached = _cached_container_str

    try:
        threading.Thread(target=_refresh_containers, daemon=True).start()
    except Exception:
        with _container_lock:
            _container_refreshing = False
    return cached


_pill_palette_cache: dict[tuple[int, ...], dict[str, int]] = {}


def _resolve_pill_palette(draw_data: DrawData) -> dict[str, int]:
    """Resolve and WCAG-repair raw 24-bit right-status pill colors (memoized)."""
    default_bg_raw = color_as_int(draw_data.default_bg) & 0xFFFFFF
    accent_bg_raw = color_as_int(draw_data.active_bg) & 0xFFFFFF
    active_fg_raw = color_as_int(draw_data.active_fg) & 0xFFFFFF
    pill_bg_raw = color_as_int(draw_data.inactive_bg) & 0xFFFFFF
    try:
        opts = get_options()
        mid_raw = color_as_int(opts.foreground) & 0xFFFFFF
        git_raw = color_as_int(opts.color2) & 0xFFFFFF
        agent_raw = color_as_int(opts.color5) & 0xFFFFFF
        cont_raw = color_as_int(opts.color6) & 0xFFFFFF
    except Exception:
        mid_raw = 0xCDCECF
        git_raw = 0x8DB9A3
        agent_raw = 0xBDA5E3
        cont_raw = 0x63CDCF
    key = (
        default_bg_raw,
        accent_bg_raw,
        active_fg_raw,
        pill_bg_raw,
        mid_raw,
        git_raw,
        agent_raw,
        cont_raw,
    )
    cached = _pill_palette_cache.get(key)
    if cached is not None:
        return cached
    pal = {
        "default_bg": default_bg_raw,
        "accent_bg": accent_bg_raw,
        "accent_fg": _ensure_contrast_rgb(active_fg_raw, accent_bg_raw),
        "pill_bg": pill_bg_raw,
        "mid_fg": _ensure_contrast_rgb(mid_raw, pill_bg_raw),
        "git_fg": _ensure_contrast_rgb(git_raw, pill_bg_raw),
        "agent_fg": _ensure_contrast_rgb(agent_raw, pill_bg_raw),
        "container_fg": _ensure_contrast_rgb(cont_raw, pill_bg_raw),
        "tmux_fg": _ensure_contrast_rgb(accent_bg_raw, pill_bg_raw),
        "bat_charging_fg": _ensure_contrast_rgb(_BAT_CHARGING_RGB, pill_bg_raw),
        "bat_low_fg": _ensure_contrast_rgb(_BAT_LOW_RGB, pill_bg_raw),
    }
    _pill_palette_cache[key] = pal
    return pal


def draw_right_status(draw_data: DrawData, screen: Screen) -> None:
    clock = get_clock()
    battery, bat_fg_custom = get_battery()
    tmux_sess = get_tmux_session()

    pal = _resolve_pill_palette(draw_data)
    default_bg = as_rgb(pal["default_bg"])
    accent_bg = as_rgb(pal["accent_bg"])
    accent_fg = as_rgb(pal["accent_fg"])
    pill_bg = as_rgb(pal["pill_bg"])
    mid_fg = as_rgb(pal["mid_fg"])
    git_fg = as_rgb(pal["git_fg"])
    agent_fg = as_rgb(pal["agent_fg"])
    container_fg = as_rgb(pal["container_fg"])
    tmux_fg = as_rgb(pal["tmux_fg"])
    if bat_fg_custom is None:
        bat_fg = mid_fg
    elif _cached_bat_raw is not None:
        bat_fg = as_rgb(_ensure_contrast_rgb(_cached_bat_raw, pal["pill_bg"]))
    else:
        bat_fg = bat_fg_custom

    # Strict "one-owner-per-signal" contract:
    # - Inside tmux: tmux already renders cwd, git, agents & containers; Kitty shows
    #   the attached session pill + machine battery + clock.
    # - Bare Kitty: Kitty owns git, agents, containers, breadcrumb, battery & clock.
    all_segments = []
    breadcrumb = ""
    git_info = ""
    agents = ""
    containers = ""

    if tmux_sess:
        all_segments.append((tmux_sess, tmux_fg, pill_bg))
    else:
        cwd = get_active_cwd()
        breadcrumb = format_breadcrumb(cwd)
        git_info = get_git_info(cwd)
        agents = get_active_agents()
        containers = get_containers()
        if git_info:
            all_segments.append((git_info, git_fg, pill_bg))
        if agents:
            all_segments.append((agents, agent_fg, pill_bg))
        if containers:
            all_segments.append((containers, container_fg, pill_bg))
        if breadcrumb:
            all_segments.append((breadcrumb, mid_fg, pill_bg))
    if battery:
        all_segments.append((battery, bat_fg, pill_bg))
    # Clock is the right anchor accent pill
    all_segments.append((clock, accent_fg, accent_bg))

    # Adaptive width fallback: gracefully drop pills from lowest priority to highest if tight
    chosen = list(all_segments)
    drop_order = [breadcrumb, battery, containers, agents, git_info, tmux_sess]
    for drop_item in drop_order:
        if not drop_item:
            continue
        total_w = sum(wcswidth(text) + 4 for text, _, _ in chosen) + (len(chosen) - 1)
        if screen.cursor.x + total_w + 2 <= screen.columns:
            break
        chosen = [s for s in chosen if s[0] != drop_item]

    if not chosen:
        if screen.cursor.x < screen.columns:
            screen.cursor.bg = default_bg
            screen.cursor.fg = default_bg
            screen.draw(" " * (screen.columns - screen.cursor.x))
        return

    total_w = sum(wcswidth(text) + 4 for text, _, _ in chosen) + (len(chosen) - 1)
    if screen.cursor.x + total_w + 1 > screen.columns:
        if screen.cursor.x < screen.columns:
            screen.cursor.bg = default_bg
            screen.cursor.fg = default_bg
            screen.draw(" " * (screen.columns - screen.cursor.x))
        return

    start_x = screen.columns - total_w - 1

    # Fill gap from last tab to start of right status pills with transparent default_bg
    if start_x > screen.cursor.x:
        gap = start_x - screen.cursor.x
        screen.cursor.bg = default_bg
        screen.cursor.fg = default_bg
        screen.draw(" " * gap)

    screen.cursor.x = start_x
    for i, (text, fg, bg) in enumerate(chosen):
        # 1. Left rounded pill cap
        screen.cursor.bg = default_bg
        screen.cursor.fg = bg
        screen.draw("")
        # 2. Pill body
        screen.cursor.bg = bg
        screen.cursor.fg = fg
        screen.draw(f" {text} ")
        # 3. Right rounded pill cap
        screen.cursor.bg = default_bg
        screen.cursor.fg = bg
        screen.draw("")
        # 4. Spacing between pills
        if i < len(chosen) - 1:
            screen.cursor.bg = default_bg
            screen.cursor.fg = default_bg
            screen.draw(" ")

    # Safety margin cell at the right edge
    if screen.cursor.x < screen.columns:
        screen.cursor.bg = default_bg
        screen.cursor.fg = default_bg
        screen.draw(" " * (screen.columns - screen.cursor.x))

    screen.cursor.reset_display_attrs()


# Process icons dictionary mapping process name -> Nerd Font icon
PROCESS_ICONS = {
    "nvim": "",
    "vim": "",
    "lazygit": "",
    "yazi": "󰇥",
    "btop": "󰓅",
    "htop": "󰓅",
    "tmux": "",
    "git": "",
    "python": "󰘧",
    "cargo": "󱘗",
    "rust": "󱘗",
    "docker": "󰡨",
    "podman": "󰡨",
    "node": "",
    "bun": "",
    "pnpm": "",
    "go": "󰟓",
    "claude": "󰚩",
    "opencode": "󰚩",
    "agent": "󰚩",
    "gemini": "󰚩",
    "herdr": "󰚩",
}
DEFAULT_PROCESS_ICON = ""


def _match_process_icon(exe: str) -> str | None:
    """Match an executable basename to PROCESS_ICONS without false-positive substrings."""
    if not exe:
        return None
    if exe in PROCESS_ICONS:
        return PROCESS_ICONS[exe]
    first_tok = re.split(r"[-_.]", exe, maxsplit=1)[0]
    if first_tok in PROCESS_ICONS:
        return PROCESS_ICONS[first_tok]
    base_tok = first_tok.rstrip("0123456789")
    if base_tok and base_tok in PROCESS_ICONS:
        return PROCESS_ICONS[base_tok]
    return None


def get_tab_icon(tab: TabBarData) -> str:
    # 1. Try to inspect running foreground process through boss if available
    try:
        boss = get_boss()
        if boss:
            t = boss.tab_for_id(tab.tab_id)
            win = (getattr(t, "active_window", None) or getattr(t, "current_window", None)) if t else None
            child = getattr(win, "child", None) if win else None
            if child:
                fp = getattr(child, "foreground_processes", None)
                if fp:
                    for p in fp:
                        cmdline = p.get("cmdline") or []
                        if cmdline:
                            icon = _match_process_icon(_extract_exe_name(cmdline[0]))
                            if icon:
                                return icon
                for attr in ("foreground_cmdline", "cmdline"):
                    cmd = getattr(child, attr, None)
                    if cmd and len(cmd) > 0:
                        icon = _match_process_icon(_extract_exe_name(cmd[0]))
                        if icon:
                            return icon
    except Exception:
        pass

    # 2. Fallback: match discrete tokens from tab title (avoid substring false-positives)
    for word in (tab.title or "").split():
        cleaned = word.strip("[](){}:,;\"'")
        if not cleaned:
            continue
        icon = _match_process_icon(_extract_exe_name(cleaned))
        if icon:
            return icon
        for subtok in re.split(r"[:/@]", cleaned):
            icon = _match_process_icon(_extract_exe_name(subtok))
            if icon:
                return icon

    return DEFAULT_PROCESS_ICON


def _is_zero_width_cp(cp: int) -> bool:
    ch = chr(cp)
    if cp < 0x20 or (0x7F <= cp <= 0x9F):
        return True
    if 0xFE00 <= cp <= 0xFE0F or 0xE0100 <= cp <= 0xE01EF:
        return True
    if 0x1F3FB <= cp <= 0x1F3FF:
        return True
    cat = unicodedata.category(ch)
    return cat in ("Mn", "Mc", "Me", "Cf")


def _cp_cell_width(cp: int) -> int:
    if _is_zero_width_cp(cp):
        return 0
    if (
        (0x1100 <= cp <= 0x115F)
        or cp in (0x2329, 0x232A)
        or (0x231A <= cp <= 0x231B)
        or (0x23E9 <= cp <= 0x23F3)
        or (0x23F8 <= cp <= 0x23FA)
        or (0x25FD <= cp <= 0x25FE)
        or (0x2600 <= cp <= 0x27BF)
        or (0x2B50 <= cp <= 0x2B55)
        or (0x1F000 <= cp <= 0x1FAFF)
        or unicodedata.east_asian_width(chr(cp)) in ("W", "F")
    ):
        return 2
    return 1


def _grapheme_clusters(text: str) -> list[tuple[str, int]]:
    """Split text into atomic visual clusters with wcwidth cell counts."""
    clusters: list[tuple[str, int]] = []
    prev_was_zwj = False
    for ch in text:
        cp = ord(ch)
        w = _cp_cell_width(cp)
        if prev_was_zwj and clusters:
            cur_s, cur_w = clusters[-1]
            clusters[-1] = (cur_s + ch, cur_w)
            prev_was_zwj = False
        elif w == 0 and clusters:
            cur_s, cur_w = clusters[-1]
            if cp == 0xFE0F and cur_w == 1:
                cur_w = 2
            clusters[-1] = (cur_s + ch, cur_w)
            prev_was_zwj = cp == 0x200D
        else:
            clusters.append((ch, w))
            prev_was_zwj = cp == 0x200D
    return clusters


def _text_display_width(text: str) -> int:
    """Measure display columns cleanly across ASCII, CJK, emoji, and ZWJ clusters."""
    if not text:
        return 0
    return sum(w for _, w in _grapheme_clusters(text))


def _truncate_right(text: str, max_cols: int) -> str:
    if max_cols <= 0:
        return ""
    clusters = _grapheme_clusters(text)
    if sum(w for _, w in clusters) <= max_cols:
        return text
    if max_cols == 1:
        return "…"
    budget = max_cols - 1
    out: list[str] = []
    used = 0
    for cluster, w in clusters:
        if used + w > budget:
            break
        out.append(cluster)
        used += w
    out.append("…")
    return "".join(out)


def _truncate_left(text: str, max_cols: int) -> str:
    if max_cols <= 0:
        return ""
    clusters = _grapheme_clusters(text)
    if sum(w for _, w in clusters) <= max_cols:
        return text
    if max_cols == 1:
        return "…"
    budget = max_cols - 1
    kept: list[str] = []
    used = 0
    for cluster, w in reversed(clusters):
        if used + w > budget:
            break
        kept.append(cluster)
        used += w
    kept.reverse()
    return "…" + "".join(kept)


def smart_truncate_title(text: str, max_cols: int) -> str:
    """Width-aware truncation appending '…', preserving command and basename for long paths."""
    if max_cols <= 0:
        return ""
    if _text_display_width(text) <= max_cols:
        return text
    if max_cols == 1:
        return "…"

    head_ctx = ""
    path_part = ""
    m = re.match(r"^(.*?\s)(~/.*|/.*)$", text)
    if m:
        head_ctx, path_part = m.group(1), m.group(2)
    elif text.startswith("/") or text.startswith("~/"):
        path_part = text

    if path_part:
        trimmed = path_part.rstrip("/")
        basename = trimmed.rsplit("/", 1)[-1] if "/" in trimmed else ""
        if basename and trimmed != basename:
            if trimmed.startswith("~/"):
                root_prefix = "~/"
                rest = trimmed[2:]
            elif trimmed.startswith("/"):
                root_prefix = "/"
                rest = trimmed[1:]
            else:
                root_prefix = ""
                rest = trimmed
            segs = [s for s in rest.split("/") if s]
            if segs:
                tail = segs[-1]
                leading_seg = root_prefix
                stop_idx = 0
                if len(segs) >= 2 and _text_display_width(f"{head_ctx}{root_prefix}{segs[0]}/…/{tail}") <= max_cols:
                    leading_seg = f"{root_prefix}{segs[0]}/"
                    stop_idx = 1

                kept_tail = tail
                for idx in range(len(segs) - 2, stop_idx, -1):
                    cand_tail = f"{segs[idx]}/{kept_tail}"
                    probe = f"{head_ctx}{leading_seg}…/{cand_tail}"
                    if _text_display_width(probe) <= max_cols:
                        kept_tail = cand_tail
                    else:
                        break

                middle = f"{head_ctx}{leading_seg}…/{kept_tail}"
                if _text_display_width(middle) <= max_cols:
                    return middle

                head_slash = f"{head_ctx}…/{tail}"
                if _text_display_width(head_slash) <= max_cols:
                    return head_slash

                ctx_w = _text_display_width(head_ctx)
                if head_ctx and 0 < ctx_w <= max_cols - 3:
                    return head_ctx + _truncate_left(f"/{tail}", max_cols - ctx_w)
                return _truncate_left(f"/{tail}", max_cols)

    return _truncate_right(text, max_cols)


def format_tab_title(tab: TabBarData, max_cols: int) -> str:
    """Format Kitty tab title matching active/window/stack markers with wcwidth truncation."""
    raw = tab.title or ""
    prefix = "▸ " if getattr(tab, "is_active", False) else ""
    num_win = getattr(tab, "num_windows", 1) or 1
    layout = getattr(tab, "layout_name", "") or ""
    suffix = (f" [{num_win}]" if num_win > 1 else "") + (" 󰁌" if layout == "stack" else "")

    budget = max_cols - _text_display_width(prefix) - _text_display_width(suffix)
    if budget >= 3:
        return f"{prefix}{smart_truncate_title(raw, budget)}{suffix}"
    return _truncate_right(f"{prefix}{raw}{suffix}", max_cols)


def draw_tab(
    draw_data: DrawData,
    screen: Screen,
    tab: TabBarData,
    before: int,
    max_title_length: int,
    index: int,
    is_last: bool,
    extra_data: ExtraData,
) -> int:
    tab_bg = as_rgb(color_as_int(draw_data.tab_bg(tab)))
    tab_fg = as_rgb(color_as_int(draw_data.tab_fg(tab)))
    default_bg = as_rgb(color_as_int(draw_data.default_bg))

    # 1. Left rounded pill cap
    screen.cursor.bg = default_bg
    screen.cursor.fg = tab_bg
    screen.draw("")

    # 2. Pill body: draw index + process icon badge + wcwidth-truncated title
    screen.cursor.bg = tab_bg
    screen.cursor.fg = tab_fg
    icon = get_tab_icon(tab)
    badge = f" {index} {icon} "
    screen.draw(badge)

    badge_width = _text_display_width(badge) if wcswidth(badge) <= 0 else wcswidth(badge)
    effective_title_len = max(1, max_title_length - badge_width - 2) if max_title_length > badge_width + 2 else max_title_length
    screen.draw(format_tab_title(tab, min(effective_title_len, 22) if max_title_length <= 0 else effective_title_len))
    screen.draw(" ")

    # 3. Right rounded pill cap
    screen.cursor.bg = default_bg
    screen.cursor.fg = tab_bg
    screen.draw("")

    end = screen.cursor.x

    # 4. Spacing between tab pills
    screen.cursor.bg = default_bg
    screen.cursor.fg = default_bg
    screen.draw(" ")

    # 5. Render right-aligned floating status pills (or clear remainder cleanly)
    if is_last and not extra_data.for_layout:
        draw_right_status(draw_data, screen)

    return end
