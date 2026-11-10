import os
import re
from kittens.tui.handler import result_handler
from kitty.key_encoding import KeyEvent, parse_shortcut

_VIM_OR_TMUX_RE = re.compile(r"^(?:g?n?vim|view|vimdiff|tmux)(?:\.exe)?$", re.I)


def is_window_vim(window, vim_id=_VIM_OR_TMUX_RE):
    fp = window.child.foreground_processes
    for p in fp:
        cmdline = p.get("cmdline") or []
        if not cmdline:
            continue
        exe = os.path.basename((cmdline[0] or "").strip())
        if not exe:
            continue
        if isinstance(vim_id, re.Pattern):
            if vim_id.match(exe):
                return True
        elif re.search(vim_id, exe, re.I):
            return True
    return False

def encode_key_mapping(window, key_mapping):
    mods, key = parse_shortcut(key_mapping)
    event = KeyEvent(
        mods=mods,
        key=key,
        shift=bool(mods & 1),
        alt=bool(mods & 2),
        ctrl=bool(mods & 4),
        super=bool(mods & 8),
        hyper=bool(mods & 16),
        meta=bool(mods & 32),
    ).as_window_system_event()
    window.write_to_child(window.encoded_key(event))

def main():
    pass

@result_handler(no_ui=True)
def handle_result(args, result, target_window_id, boss):
    w = boss.window_id_map.get(target_window_id)
    if w is None:
        return
    direction = args[1]
    key_mapping = args[2]
    tab = boss.active_tab

    if is_window_vim(w, _VIM_OR_TMUX_RE) or tab is None or len(tab.windows) <= 1:
        encode_key_mapping(w, key_mapping)
    else:
        tab.neighboring_window(direction)
