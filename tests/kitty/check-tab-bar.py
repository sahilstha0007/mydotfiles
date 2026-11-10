#!/usr/bin/env python3
"""Unit tests for Kitty tab_bar.py caching/matching, pass_keys.py, and custom.conf."""

import glob
import os
import subprocess
import sys
import tempfile
import time
import types
import unittest
from dataclasses import dataclass
from pathlib import Path
from unittest import mock

REPO_ROOT = Path(__file__).resolve().parents[2]
KITTY_DIR = REPO_ROOT / ".config" / "kitty"


def _install_kitty_stubs_if_needed() -> None:
    """Provide lightweight kitty/kittens stubs when executed outside `kitty +runpy`."""
    if str(KITTY_DIR) not in sys.path:
        sys.path.insert(0, str(KITTY_DIR))

    try:
        import kitty.fast_data_types  # noqa: F401
        import kitty.key_encoding  # noqa: F401
        import kitty.tab_bar  # noqa: F401
        import kittens.tui.handler  # noqa: F401
        return
    except ImportError:
        pass

    kitty_pkg = types.ModuleType("kitty")
    fast_data_types = types.ModuleType("kitty.fast_data_types")
    tab_bar_mod = types.ModuleType("kitty.tab_bar")
    key_encoding = types.ModuleType("kitty.key_encoding")

    class Screen:
        pass

    def get_options():
        return types.SimpleNamespace(
            foreground=0xCDCECF,
            color2=0x81B29A,
            color5=0x9D79D6,
            color6=0x63CDCF,
        )

    fast_data_types.Screen = Screen
    fast_data_types.get_options = get_options

    @dataclass
    class TabBarData:
        title: str
        is_active: bool = False
        needs_attention: bool = False
        tab_id: int = -1
        os_window_id: int = 0
        num_windows: int = 0
        num_window_groups: int = 0
        layout_name: str = ""

    class DrawData:
        pass

    class ExtraData:
        pass

    tab_bar_mod.DrawData = DrawData
    tab_bar_mod.ExtraData = ExtraData
    tab_bar_mod.TabBarData = TabBarData
    tab_bar_mod.as_rgb = lambda c: (c << 8) | 2
    tab_bar_mod.color_as_int = lambda c: int(c)
    tab_bar_mod.draw_title = lambda *a, **kw: None
    tab_bar_mod.get_boss = lambda: None
    tab_bar_mod.wcswidth = lambda s: len(s)

    class KeyEvent:
        def __init__(self, **kwargs):
            self.kwargs = kwargs

        def as_window_system_event(self):
            return self.kwargs

    def parse_shortcut(mapping: str):
        parts = mapping.lower().split("+")
        key = parts[-1]
        mods = 0
        mod_bits = {"shift": 1, "alt": 2, "ctrl": 4, "super": 8, "hyper": 16, "meta": 32}
        for mod in parts[:-1]:
            mods |= mod_bits.get(mod, 0)
        return mods, key

    key_encoding.KeyEvent = KeyEvent
    key_encoding.parse_shortcut = parse_shortcut

    kittens_pkg = types.ModuleType("kittens")
    kittens_tui = types.ModuleType("kittens.tui")
    kittens_handler = types.ModuleType("kittens.tui.handler")
    kittens_handler.result_handler = lambda **kwargs: (lambda fn: fn)

    sys.modules["kitty"] = kitty_pkg
    sys.modules["kitty.fast_data_types"] = fast_data_types
    sys.modules["kitty.tab_bar"] = tab_bar_mod
    sys.modules["kitty.key_encoding"] = key_encoding
    sys.modules["kittens"] = kittens_pkg
    sys.modules["kittens.tui"] = kittens_tui
    sys.modules["kittens.tui.handler"] = kittens_handler


_install_kitty_stubs_if_needed()

import pass_keys  # noqa: E402
import tab_bar  # noqa: E402
from kitty.tab_bar import TabBarData  # noqa: E402


class _FakeClock:
    def __init__(self, initial: float = 100.0):
        self.now = initial

    def __call__(self) -> float:
        return self.now


class _FakeWindow:
    def __init__(self, cmdlines, window_id: int = 1):
        self.id = window_id
        self.child = types.SimpleNamespace(
            foreground_processes=[{"cmdline": cmd} for cmd in cmdlines],
            foreground_cmdline=cmdlines[0] if cmdlines else [],
            cmdline=cmdlines[0] if cmdlines else [],
        )
        self.encoded_calls = []
        self.written_calls = []

    def encoded_key(self, event):
        self.encoded_calls.append(event)
        return f"ENCODED:{event}"

    def write_to_child(self, data):
        self.written_calls.append(data)


class _FakeTab:
    def __init__(self, windows, tab_id: int = 1):
        self.windows = list(windows)
        self.tab_id = tab_id
        self.active_window = self.windows[0] if self.windows else None
        self.navigated = []

    def __iter__(self):
        return iter(self.windows)

    def neighboring_window(self, direction: str) -> None:
        self.navigated.append(direction)


class _FakeBoss:
    def __init__(self, tabs):
        self.all_tabs = list(tabs)
        self.active_tab = self.all_tabs[0] if self.all_tabs else None
        self.window_id_map = {
            w.id: w for t in self.all_tabs for w in t.windows
        }
        self._tabs_by_id = {t.tab_id: t for t in self.all_tabs}

    def tab_for_id(self, tab_id: int):
        return self._tabs_by_id.get(tab_id)


def _wait_until(predicate, timeout: float = 1.0) -> None:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if predicate():
            return
        time.sleep(0.005)
    raise AssertionError("Timed out waiting for background refresh")


class KittyTabBarTests(unittest.TestCase):
    def setUp(self) -> None:
        tab_bar._last_bat_query = 0.0
        tab_bar._cached_bat_str = ""
        tab_bar._cached_bat_fg = None
        tab_bar._POWER_SUPPLY_DIR = "/sys/class/power_supply"

        tab_bar._last_git_query = 0.0
        tab_bar._last_git_cwd = ""
        tab_bar._cached_git_str = ""

        tab_bar._last_tmux_query = 0.0
        tab_bar._cached_tmux_str = ""

        with tab_bar._agent_lock:
            tab_bar._last_agent_query = 0.0
            tab_bar._cached_agent_str = ""
            tab_bar._cached_tmux_agent_str = ""
            tab_bar._agent_refreshing = False

        with tab_bar._container_lock:
            tab_bar._last_container_query = 0.0
            tab_bar._cached_container_str = ""
            tab_bar._container_refreshing = False

    def test_empty_containers_cached_within_ttl_and_non_blocking(self) -> None:
        clock = _FakeClock(100.0)
        run_calls = 0

        def fake_run(cmd, **kwargs):
            nonlocal run_calls
            run_calls += 1
            time.sleep(0.08)
            stdout = "" if run_calls == 1 else "c1\nc2\n"
            return subprocess.CompletedProcess(cmd, 0, stdout=stdout)

        with (
            mock.patch.object(tab_bar.time, "monotonic", side_effect=clock),
            mock.patch.object(
                tab_bar.shutil,
                "which",
                side_effect=lambda name: "/usr/bin/podman" if name == "podman" else None,
            ),
            mock.patch.object(tab_bar.subprocess, "run", side_effect=fake_run),
        ):
            t0 = time.monotonic()
            first = tab_bar.get_containers()
            elapsed = time.monotonic() - t0
            self.assertEqual(first, "")
            self.assertLess(elapsed, 0.04, "get_containers() blocked the UI thread")

            _wait_until(lambda: not tab_bar._container_refreshing)
            self.assertEqual(run_calls, 1)
            self.assertGreater(tab_bar._last_container_query, 0.0)

            # Subsequent calls inside 10s TTL must hit empty cache without invoking podman
            clock.now = 105.0
            self.assertEqual(tab_bar.get_containers(), "")
            self.assertEqual(tab_bar.get_containers(), "")
            self.assertEqual(run_calls, 1)

            # After TTL expires, background refresh updates cached count
            clock.now = 111.0
            self.assertEqual(tab_bar.get_containers(), "")
            _wait_until(lambda: not tab_bar._container_refreshing)
            self.assertEqual(run_calls, 2)
            self.assertEqual(tab_bar.get_containers(), "󰡨 2")

    def test_empty_agents_tmux_fallback_cached_within_ttl(self) -> None:
        clock = _FakeClock(200.0)
        run_calls = 0
        boss = _FakeBoss([_FakeTab([_FakeWindow([["zsh"]])])])

        def fake_run(cmd, **kwargs):
            nonlocal run_calls
            run_calls += 1
            return subprocess.CompletedProcess(cmd, 0, stdout="zsh\nvim\n")

        with (
            mock.patch.object(tab_bar.time, "monotonic", side_effect=clock),
            mock.patch.object(tab_bar, "get_boss", return_value=boss),
            mock.patch.dict(os.environ, {"TMUX_TMPDIR": "/tmp/tmux-test"}, clear=False),
            mock.patch.object(
                tab_bar.shutil,
                "which",
                side_effect=lambda name: "/usr/bin/tmux" if name == "tmux" else None,
            ),
            mock.patch.object(tab_bar.subprocess, "run", side_effect=fake_run),
        ):
            self.assertEqual(tab_bar.get_active_agents(), "")
            _wait_until(lambda: not tab_bar._agent_refreshing)
            self.assertEqual(run_calls, 1)
            self.assertGreater(tab_bar._last_agent_query, 0.0)

            clock.now = 204.0
            self.assertEqual(tab_bar.get_active_agents(), "")
            self.assertEqual(tab_bar.get_active_agents(), "")
            self.assertEqual(run_calls, 1)

    def test_empty_tmux_session_cached_within_ttl(self) -> None:
        clock = _FakeClock(300.0)
        run_calls = 0
        boss = _FakeBoss([_FakeTab([_FakeWindow([["tmux"]])])])

        def fake_run(cmd, **kwargs):
            nonlocal run_calls
            run_calls += 1
            return subprocess.CompletedProcess(cmd, 0, stdout="")

        with (
            mock.patch.object(tab_bar.time, "monotonic", side_effect=clock),
            mock.patch.object(tab_bar, "get_boss", return_value=boss),
            mock.patch.object(tab_bar.subprocess, "run", side_effect=fake_run),
        ):
            self.assertEqual(tab_bar.get_tmux_session(), "")
            self.assertEqual(run_calls, 1)

            clock.now = 304.0
            self.assertEqual(tab_bar.get_tmux_session(), "")
            self.assertEqual(tab_bar.get_tmux_session(), "")
            self.assertEqual(run_calls, 1)

    def test_battery_empty_cached_within_ttl_and_scans_bat_glob(self) -> None:
        clock = _FakeClock(400.0)
        with tempfile.TemporaryDirectory() as tmpdir:
            tab_bar._POWER_SUPPLY_DIR = tmpdir
            glob_calls = 0
            real_glob = glob.glob

            def counting_glob(pattern):
                nonlocal glob_calls
                glob_calls += 1
                return real_glob(pattern)

            with (
                mock.patch.object(tab_bar.time, "monotonic", side_effect=clock),
                mock.patch.object(tab_bar.glob, "glob", side_effect=counting_glob),
            ):
                self.assertEqual(tab_bar.get_battery(), ("", None))
                self.assertEqual(glob_calls, 1)

                clock.now = 415.0
                self.assertEqual(tab_bar.get_battery(), ("", None))
                self.assertEqual(glob_calls, 1)

            # Verify BAT1 (not only BAT0) is discovered after cache expires
            bat1 = Path(tmpdir) / "BAT1"
            bat1.mkdir()
            (bat1 / "capacity").write_text("64\n")
            (bat1 / "status").write_text("Discharging\n")

            clock.now = 425.0
            with mock.patch.object(tab_bar.time, "monotonic", side_effect=clock):
                self.assertEqual(tab_bar.get_battery(), ("󰁿 64%", None))

            (bat1 / "status").write_text("Charging\n")
            clock.now = 450.0
            with mock.patch.object(tab_bar.time, "monotonic", side_effect=clock):
                bat_str, bat_fg = tab_bar.get_battery()
                self.assertEqual(bat_str, "󰂄 64%")
                self.assertIsNotNone(bat_fg)

    def test_git_info_caches_empty_result_with_sentinel(self) -> None:
        clock = _FakeClock(500.0)
        with tempfile.TemporaryDirectory() as tmpdir:
            exists_calls = 0
            real_exists = os.path.exists

            def counting_exists(path):
                nonlocal exists_calls
                exists_calls += 1
                return real_exists(path)

            with (
                mock.patch.object(tab_bar.time, "monotonic", side_effect=clock),
                mock.patch.object(tab_bar.os.path, "exists", side_effect=counting_exists),
            ):
                self.assertEqual(tab_bar.get_git_info(tmpdir), "")
                first_calls = exists_calls
                self.assertGreater(first_calls, 0)

                clock.now = 502.0
                self.assertEqual(tab_bar.get_git_info(tmpdir), "")
                self.assertEqual(exists_calls, first_calls)

    def test_agent_names_exact_matching(self) -> None:
        clock = _FakeClock(600.0)

        # False-positive traps: "example" contains "amp", "omniroute" contains "omni"
        decoy_boss = _FakeBoss([
            _FakeTab([
                _FakeWindow([["example"], ["/usr/local/bin/omniroute"]]),
            ])
        ])
        with (
            mock.patch.object(tab_bar.time, "monotonic", side_effect=clock),
            mock.patch.object(tab_bar, "get_boss", return_value=decoy_boss),
            mock.patch.dict(os.environ, {"TMUX_TMPDIR": ""}, clear=False),
        ):
            self.assertEqual(tab_bar.get_active_agents(), "")

        # Real match: claude
        tab_bar._last_agent_query = 0.0
        claude_boss = _FakeBoss([_FakeTab([_FakeWindow([["claude"]])])])
        with (
            mock.patch.object(tab_bar.time, "monotonic", side_effect=clock),
            mock.patch.object(tab_bar, "get_boss", return_value=claude_boss),
        ):
            self.assertEqual(tab_bar.get_active_agents(), "󰚩 claude")

        # Real match: /usr/bin/opencode
        tab_bar._last_agent_query = 0.0
        opencode_boss = _FakeBoss([_FakeTab([_FakeWindow([["/usr/bin/opencode"]])])])
        with (
            mock.patch.object(tab_bar.time, "monotonic", side_effect=clock),
            mock.patch.object(tab_bar, "get_boss", return_value=opencode_boss),
        ):
            self.assertEqual(tab_bar.get_active_agents(), "󰚩 opencode")

        # Tmux fallback must also reject "example" and "omniroute" while matching "/usr/bin/opencode"
        tab_bar._last_agent_query = 0.0
        tab_bar._cached_tmux_agent_str = ""
        empty_boss = _FakeBoss([_FakeTab([_FakeWindow([["zsh"]])])])
        with (
            mock.patch.object(tab_bar.time, "monotonic", side_effect=clock),
            mock.patch.object(tab_bar, "get_boss", return_value=empty_boss),
            mock.patch.dict(os.environ, {"TMUX_TMPDIR": "/tmp/tmux-test"}, clear=False),
            mock.patch.object(tab_bar.shutil, "which", return_value="/usr/bin/tmux"),
            mock.patch.object(
                tab_bar.subprocess,
                "run",
                return_value=subprocess.CompletedProcess(
                    ["tmux"], 0, stdout="example\nomniroute\n/usr/bin/opencode\n"
                ),
            ),
        ):
            tab_bar.get_active_agents()
            _wait_until(lambda: not tab_bar._agent_refreshing)
            self.assertEqual(tab_bar.get_active_agents(), "󰚩 opencode")

    def test_get_tab_icon_avoids_false_positives(self) -> None:
        chrome_win = _FakeWindow([["/usr/bin/google-chrome"]], window_id=1)
        escargot_win = _FakeWindow([["escargot"]], window_id=2)
        nvim_win = _FakeWindow([["zsh"], ["/usr/bin/nvim", "init.lua"]], window_id=3)
        py_win = _FakeWindow([["python3.12", "app.py"]], window_id=4)

        boss = _FakeBoss([
            _FakeTab([chrome_win], tab_id=1),
            _FakeTab([escargot_win], tab_id=2),
            _FakeTab([nvim_win], tab_id=3),
            _FakeTab([py_win], tab_id=4),
        ])

        with mock.patch.object(tab_bar, "get_boss", return_value=boss):
            self.assertEqual(
                tab_bar.get_tab_icon(TabBarData(title="google-chrome", tab_id=1)),
                tab_bar.DEFAULT_PROCESS_ICON,
            )
            self.assertEqual(
                tab_bar.get_tab_icon(TabBarData(title="escargot", tab_id=2)),
                tab_bar.DEFAULT_PROCESS_ICON,
            )
            self.assertEqual(
                tab_bar.get_tab_icon(TabBarData(title="zsh", tab_id=3)),
                tab_bar.PROCESS_ICONS["nvim"],
            )
            self.assertEqual(
                tab_bar.get_tab_icon(TabBarData(title="python3.12 app.py", tab_id=4)),
                tab_bar.PROCESS_ICONS["python"],
            )

    def test_pass_keys_one_window_shell_passes_ctrl_l_through(self) -> None:
        win = _FakeWindow([["zsh"]], window_id=1)
        tab = _FakeTab([win], tab_id=1)
        boss = _FakeBoss([tab])

        pass_keys.handle_result(["pass_keys.py", "right", "ctrl+l"], None, 1, boss)

        self.assertEqual(len(win.written_calls), 1)
        self.assertEqual(tab.navigated, [])

    def test_pass_keys_two_window_shell_navigates(self) -> None:
        win1 = _FakeWindow([["zsh"]], window_id=1)
        win2 = _FakeWindow([["zsh"]], window_id=2)
        tab = _FakeTab([win1, win2], tab_id=1)
        boss = _FakeBoss([tab])

        pass_keys.handle_result(["pass_keys.py", "right", "ctrl+l"], None, 1, boss)

        self.assertEqual(tab.navigated, ["right"])
        self.assertEqual(win1.written_calls, [])

    def test_pass_keys_two_window_nvim_passes_ctrl_l_through(self) -> None:
        win1 = _FakeWindow([["/usr/bin/nvim", "init.lua"]], window_id=1)
        win2 = _FakeWindow([["zsh"]], window_id=2)
        tab = _FakeTab([win1, win2], tab_id=1)
        boss = _FakeBoss([tab])

        pass_keys.handle_result(["pass_keys.py", "right", "ctrl+l"], None, 1, boss)

        self.assertEqual(len(win1.written_calls), 1)
        self.assertEqual(tab.navigated, [])

    def test_custom_conf_hud_and_remote_control(self) -> None:
        conf = (KITTY_DIR / "custom.conf").read_text()
        self.assertIn("tab_bar_min_tabs 1", conf)
        self.assertIn("allow_remote_control socket-only", conf)
        self.assertIn('tab_title_template "{title[:22]}"', conf)
        self.assertIn("▸ {title[:22]}", conf)
        self.assertNotIn("title.split()", conf)


if __name__ == "__main__":
    unittest.main(verbosity=2)
