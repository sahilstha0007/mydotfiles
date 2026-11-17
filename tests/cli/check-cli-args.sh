#!/usr/bin/env bash
# E2: Bad-arg and --help matrix for all stack CLI scripts (bounded via `timeout 5`, zero hangs).
set -euo pipefail

SELF_PATH=$(readlink -f -- "${BASH_SOURCE[0]}")
REPO_ROOT=$(cd -- "$(dirname -- "$SELF_PATH")/../.." && pwd -P)

# Ensure bin/ symlinks or direct scripts resolve under repo root
CLI_HUB="$REPO_ROOT/bin/project-hub"
CLI_TASK="$REPO_ROOT/bin/project-task"
CLI_CHEAT="$REPO_ROOT/bin/terminal-cheatsheet"
CLI_DUMP="$REPO_ROOT/.config/tmux/keymap-dump.sh"
CLI_SYNC="$REPO_ROOT/bin/sync-keybindings"
CLI_RELOAD="$REPO_ROOT/bin/stack-reload"
CLI_INSTALL="$REPO_ROOT/install.sh"

check_case() {
  local label="$1" want_rc="$2" err_pattern="$3"
  shift 3
  local out_file rc=0
  out_file=$(mktemp)
  if timeout 5 "$@" </dev/null >"$out_file.stdout" 2>"$out_file.stderr"; then
    rc=0
  else
    rc=$?
  fi
  local stderr_txt stdout_txt pat_ok=0 tb_found=0
  stderr_txt=$(cat "$out_file.stderr")
  stdout_txt=$(cat "$out_file.stdout")
  if [ -z "$err_pattern" ] || grep -qiE "$err_pattern" "$out_file.stderr" "$out_file.stdout"; then
    pat_ok=1
  fi
  if grep -q 'Traceback (most recent call last)' "$out_file.stderr"; then
    tb_found=1
  fi
  rm -f "$out_file" "$out_file.stdout" "$out_file.stderr"

  if [ "$rc" -eq 124 ]; then
    echo "FAIL [$label]: hung past 5s timeout" >&2
    exit 1
  fi
  if [ "$rc" -ne "$want_rc" ]; then
    echo "FAIL [$label]: expected exit $want_rc, got $rc (stderr: $stderr_txt)" >&2
    exit 1
  fi
  if [ "$pat_ok" -ne 1 ]; then
    echo "FAIL [$label]: expected pattern '$err_pattern', got stdout='$stdout_txt' stderr='$stderr_txt'" >&2
    exit 1
  fi
  if [ "$tb_found" -eq 1 ]; then
    echo "FAIL [$label]: leaked Python traceback on stderr" >&2
    exit 1
  fi
  echo "  PASS  $label (exit=$rc)"
}

check_case "project-hub --help"         0 "usage:"     bash "$CLI_HUB" --help
check_case "project-hub --bad-flag"     2 "unknown"    bash "$CLI_HUB" --bad-flag
check_case "project-hub --preview bad"  2 "requires"   bash "$CLI_HUB" --preview

check_case "project-task --help"        0 "usage:"     python3 "$CLI_TASK" --help
check_case "project-task --bad-flag"    2 "unknown"    python3 "$CLI_TASK" --bad-flag
check_case "project-task test --bad"    2 "unknown"    python3 "$CLI_TASK" test --bad-flag

check_case "cheatsheet --help"          0 "usage:"     python3 "$CLI_CHEAT" --help
check_case "cheatsheet --bad-flag"      2 "unknown"    python3 "$CLI_CHEAT" --bad-flag
check_case "cheatsheet --table"         0 "UNIFIED"    python3 "$CLI_CHEAT" --table

check_case "keymap-dump --help"         0 "usage:"     bash "$CLI_DUMP" --help
check_case "keymap-dump --bad-flag"     2 "unknown"    bash "$CLI_DUMP" --bad-flag

check_case "sync-keybindings --help"    0 "usage:"     python3 "$CLI_SYNC" --help
check_case "sync-keybindings --bad"     2 "unknown"    python3 "$CLI_SYNC" --bad-flag

check_case "stack-reload --help"        0 "usage:"     bash "$CLI_RELOAD" --help
check_case "stack-reload --bad-flag"    2 "unknown"    bash "$CLI_RELOAD" --bad-flag

check_case "install.sh --help"            0 "usage:"     bash "$CLI_INSTALL" --help
check_case "install.sh --bad-flag"        2 "unknown"    bash "$CLI_INSTALL" --bad-flag
