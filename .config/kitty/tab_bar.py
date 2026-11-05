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
import os
import subprocess
import time
from kitty.fast_data_types import Screen
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

# In-memory caches to eliminate redundant kernel/fs calls
_last_bat_query = 0.0
_cached_bat_str = ""
_cached_bat_fg = None

_last_git_query = 0.0
_last_git_cwd = ""
_cached_git_str = ""

_last_tmux_query = 0.0
_cached_tmux_str = ""

_last_agent_query = 0.0
_cached_agent_str = ""

_last_container_query = 0.0
_cached_container_str = ""


def get_battery() -> tuple[str, int | None]:
    global _last_bat_query, _cached_bat_str, _cached_bat_fg
    now = time.monotonic()
    if now - _last_bat_query < 20.0 and _cached_bat_str:
        return _cached_bat_str, _cached_bat_fg
    _last_bat_query = now
    try:
        cap_file = "/sys/class/power_supply/BAT0/capacity"
        stat_file = "/sys/class/power_supply/BAT0/status"
        if os.path.exists(cap_file):
            with open(cap_file, "r") as f:
                cap = int(f.read().strip())
            stat = ""
            if os.path.exists(stat_file):
                with open(stat_file, "r") as f:
                    stat = f.read().strip().lower()
            if "charging" in stat:
                icon = "󰂄"
                fg = as_rgb(0xe0af68)
            elif "full" in stat or cap >= 98:
                _cached_bat_str = ""
                _cached_bat_fg = None
                return _cached_bat_str, _cached_bat_fg
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
        pass
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
    if cwd == _last_git_cwd and now - _last_git_query < 3.0:
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
    if now - _last_tmux_query < 5.0 and _cached_tmux_str:
        return _cached_tmux_str
    _last_tmux_query = now
    try:
        boss = get_boss()
        is_tmux = False
        if boss and boss.active_tab and boss.active_tab.active_window:
            child = boss.active_tab.active_window.child
            if child and child.foreground_processes:
                is_tmux = any("tmux" in (p.get("cmdline", [""])[0] if p.get("cmdline") else "") for p in child.foreground_processes)
        if is_tmux or os.environ.get("TMUX"):
            res = subprocess.run(["tmux", "display-message", "-p", "#S"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, timeout=0.1)
            name = res.stdout.strip()
            if name:
                _cached_tmux_str = f" {name}"
                return _cached_tmux_str
    except Exception:
        pass
    _cached_tmux_str = ""
    return _cached_tmux_str


def get_active_agents() -> str:
    global _last_agent_query, _cached_agent_str
    now = time.monotonic()
    if now - _last_agent_query < 5.0 and _cached_agent_str:
        return _cached_agent_str
    _last_agent_query = now
    try:
        agent_names = set()
        boss = get_boss()
        if boss:
            for tab in boss.all_tabs:
                for window in tab:
                    child = window.child
                    if child and child.foreground_processes:
                        for p in child.foreground_processes:
                            cmd = (p.get("cmdline", [""])[0] if p.get("cmdline") else "").lower()
                            for name in ("claude", "opencode", "herdr", "gemini", "aider", "copilot"):
                                if name in cmd:
                                    agent_names.add(name)
        if not agent_names:
            res = subprocess.run(
                ["pgrep", "-a", "-f", "claude|opencode|herdr|gemini|aider"],
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True,
                timeout=0.08,
            )
            for line in res.stdout.strip().split("\n"):
                line_lower = line.lower()
                for name in ("claude", "opencode", "herdr", "gemini", "aider"):
                    if name in line_lower and "grep" not in line_lower and "tab_bar" not in line_lower and "test" not in line_lower:
                        agent_names.add(name)
                        break

        if agent_names:
            if len(agent_names) == 1:
                _cached_agent_str = f"󰚩 {next(iter(agent_names))}"
            else:
                _cached_agent_str = f"󰚩 {len(agent_names)} agents"
            return _cached_agent_str
    except Exception:
        pass
    _cached_agent_str = ""
    return _cached_agent_str


def get_containers() -> str:
    global _last_container_query, _cached_container_str
    now = time.monotonic()
    if now - _last_container_query < 10.0 and _cached_container_str:
        return _cached_container_str
    _last_container_query = now
    try:
        res = subprocess.run(["podman", "ps", "-q"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, timeout=0.1)
        lines = [l for l in res.stdout.strip().split("\n") if l]
        count = len(lines)
        if count == 0:
            res_d = subprocess.run(["docker", "ps", "-q"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, timeout=0.1)
            lines_d = [l for l in res_d.stdout.strip().split("\n") if l]
            count = len(lines_d)
        if count > 0:
            _cached_container_str = f"󰡨 {count}"
            return _cached_container_str
    except Exception:
        pass
    _cached_container_str = ""
    return _cached_container_str


def draw_right_status(draw_data: DrawData, screen: Screen) -> None:
    cwd = get_active_cwd()
    clock = get_clock()
    battery, bat_fg_custom = get_battery()
    breadcrumb = format_breadcrumb(cwd)
    git_info = get_git_info(cwd)
    tmux_sess = get_tmux_session()
    agents = get_active_agents()
    containers = get_containers()

    default_bg = as_rgb(color_as_int(draw_data.default_bg))
    accent_bg = as_rgb(color_as_int(draw_data.active_bg))
    accent_fg = as_rgb(color_as_int(draw_data.active_fg))
    pill_bg = as_rgb(0x03195b)
    mid_fg = as_rgb(0xcbe9fd)
    git_fg = as_rgb(0x81b29a)
    tmux_fg = as_rgb(0x3781fc)
    agent_fg = as_rgb(0xbaa1e2)
    container_fg = as_rgb(0x7ad5d6)
    bat_fg = bat_fg_custom if bat_fg_custom is not None else mid_fg

    # All candidate pill segments: (content, fg, bg)
    all_segments = []
    if tmux_sess:
        all_segments.append((tmux_sess, tmux_fg, pill_bg))
    if agents:
        all_segments.append((agents, agent_fg, pill_bg))
    if containers:
        all_segments.append((containers, container_fg, pill_bg))
    if git_info:
        all_segments.append((git_info, git_fg, pill_bg))
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
        return

    total_w = sum(wcswidth(text) + 4 for text, _, _ in chosen) + (len(chosen) - 1)
    if screen.cursor.x + total_w + 1 > screen.columns:
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


def get_tab_icon(tab: TabBarData) -> str:
    # 1. Try to inspect running process through boss if available
    try:
        boss = get_boss()
        if boss:
            t = boss.tab_for_id(tab.tab_id)
            if t and t.current_window:
                cmd = getattr(t.current_window.child, "cmdline", None)
                if cmd and len(cmd) > 0:
                    exe = os.path.basename(cmd[0]).lower()
                    for name, icon in PROCESS_ICONS.items():
                        if name in exe:
                            return icon
    except Exception:
        pass

    # 2. Fallback: match from tab title
    title_lower = (tab.title or "").lower()
    for name, icon in PROCESS_ICONS.items():
        if name in title_lower:
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

    # 5. Clear remainder of the bar to transparent (clean minimal tab-only topbar)
    if is_last and not extra_data.for_layout:
        if screen.cursor.x < screen.columns:
            screen.cursor.bg = default_bg
            screen.cursor.fg = default_bg
            screen.draw(" " * (screen.columns - screen.cursor.x))

    return end
