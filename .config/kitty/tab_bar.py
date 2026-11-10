# =============================================================================
# Kitty Custom Tab Bar: Modern Floating Rounded Pills HUD
# Features:
#   - Floating rounded pill tabs ( ... ) harmonized with Nightfox palette
#   - Dynamic process badges ( nvim,  lazygit, 󰇥 yazi, 󰓅 btop,  tmux, 󰡨 docker, 󰚩 ai)
#   - Floating right-aligned status pills: Tmux, AI Agents, Containers, Git, CWD, Battery, Clock
#   - Adaptive width folding: gracefully drops breadcrumb/battery/containers on narrow screens
#   - Zero performance overhead: event-driven rendering + cached sysfs queries
# =============================================================================

import datetime
import glob
import os
import re
import shutil
import subprocess
import threading
import time
from kitty.fast_data_types import Screen, get_options
from kitty.tab_bar import (
    DrawData,
    ExtraData,
    TabBarData,
    as_rgb,
    color_as_int,
    draw_title,
    get_boss,
    wcswidth,
)

_POWER_SUPPLY_DIR = "/sys/class/power_supply"

# In-memory caches to eliminate redundant kernel/fs calls
_last_bat_query = 0.0
_cached_bat_str = ""
_cached_bat_fg = None

_last_git_query = 0.0
_last_git_cwd = ""
_cached_git_str = ""

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


def get_battery() -> tuple[str, int | None]:
    global _last_bat_query, _cached_bat_str, _cached_bat_fg
    now = time.monotonic()
    if _last_bat_query > 0.0 and now - _last_bat_query < 20.0:
        return _cached_bat_str, _cached_bat_fg
    _last_bat_query = now
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
            if stat == "charging":
                icon = "󰂄"
                fg = as_rgb(0xe0af68)
            elif stat == "full" or cap >= 98:
                continue
            elif cap >= 80:
                icon = "󰁹"
                fg = None
            elif cap >= 50:
                icon = "󰁿"
                fg = None
            elif cap >= 20:
                icon = "󰁼"
                fg = None
            else:
                icon = "󰁺"
                fg = as_rgb(0xe0c989)
            _cached_bat_str = f"{icon} {cap}%"
            _cached_bat_fg = fg
            return _cached_bat_str, _cached_bat_fg
        except Exception:
            continue
    _cached_bat_str = ""
    _cached_bat_fg = None
    return _cached_bat_str, _cached_bat_fg


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


def get_tmux_session() -> str:
    global _last_tmux_query, _cached_tmux_str
    now = time.monotonic()
    if _last_tmux_query > 0.0 and now - _last_tmux_query < 5.0:
        return _cached_tmux_str
    _last_tmux_query = now
    try:
        boss = get_boss()
        is_tmux = False
        if boss and boss.active_tab and boss.active_tab.active_window:
            child = boss.active_tab.active_window.child
            if child and child.foreground_processes:
                for p in child.foreground_processes:
                    cmdline = p.get("cmdline") or []
                    exe = _extract_exe_name(cmdline[0]) if cmdline else ""
                    if exe == "tmux" or exe.startswith("tmux:"):
                        is_tmux = True
                        break
        if is_tmux or os.environ.get("TMUX"):
            res = subprocess.run(
                ["tmux", "display-message", "-p", "#S"],
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True,
                timeout=0.05,
            )
            name = res.stdout.strip() if getattr(res, "returncode", 0) == 0 else ""
            if name:
                _cached_tmux_str = f" {name}"
                return _cached_tmux_str
    except Exception:
        pass
    _cached_tmux_str = ""
    return _cached_tmux_str


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

    if os.environ.get("TMUX_TMPDIR") and shutil.which("tmux"):
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
                timeout=0.3,
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
        if not any(shutil.which(r) for r in ("podman", "docker")):
            _cached_container_str = ""
            _last_container_query = now
            return _cached_container_str
        _container_refreshing = True
        cached = _cached_container_str

    try:
        threading.Thread(target=_refresh_containers, daemon=True).start()
    except Exception:
        with _container_lock:
            _container_refreshing = False
    return cached


def draw_right_status(draw_data: DrawData, screen: Screen) -> None:
    clock = get_clock()
    battery, bat_fg_custom = get_battery()
    tmux_sess = get_tmux_session()

    default_bg = as_rgb(color_as_int(draw_data.default_bg))
    accent_bg = as_rgb(color_as_int(draw_data.active_bg))
    accent_fg = as_rgb(color_as_int(draw_data.active_fg))
    pill_bg = as_rgb(color_as_int(draw_data.inactive_bg))
    # Derive semantic pill foregrounds from active Kitty palette (Nightfox fallback if unavailable)
    try:
        opts = get_options()
        mid_fg = as_rgb(color_as_int(opts.foreground))
        git_fg = as_rgb(color_as_int(opts.color2))
        agent_fg = as_rgb(color_as_int(opts.color5))
        container_fg = as_rgb(color_as_int(opts.color6))
    except Exception:
        mid_fg = as_rgb(0xcdcecf)
        git_fg = as_rgb(0x81b29a)
        agent_fg = as_rgb(0x9d79d6)
        container_fg = as_rgb(0x63cdcf)
    tmux_fg = accent_bg
    bat_fg = bat_fg_custom if bat_fg_custom is not None else mid_fg

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

    # 2. Pill body: draw index + process icon badge + title
    screen.cursor.bg = tab_bg
    screen.cursor.fg = tab_fg
    icon = get_tab_icon(tab)
    badge = f" {index} {icon} "
    screen.draw(badge)

    badge_width = wcswidth(badge)
    effective_title_len = max(1, max_title_length - badge_width - 2) if max_title_length > badge_width + 2 else max_title_length
    draw_title(draw_data, screen, tab, index, effective_title_len)
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
