#!/usr/bin/env bash
# Run every nvim spec headless. Exits non-zero if any spec fails.
#
# The specs use a two-channel failure protocol, and BOTH channels have to be
# watched. Getting this wrong is not hypothetical:
#
#   1. A failing assertion prints a line starting "FAIL: " and carries on.
#      Exit code is always 0, so grepping the exit code reports green on a
#      suite where every check failed.
#   2. A spec that calls error() — a missing fixture, a bad path — dies before
#      it prints anything. There is no FAIL line, and the exit code is still 0.
#
# Channel 2 is how tests/opencode_harness_spec.lua sat red for an unknown
# stretch: it throws at line 112 on a fixture that no longer exists, and this
# script called it "ok". So: FAIL lines AND a non-zero exit AND the E-codes
# nvim uses for an aborted chunk. All three, or the suite lies to you.
set -uo pipefail
repo_root="$(cd "$(dirname "$0")/../../.." && pwd)"
tests_dir="$repo_root/tests/nvim"
cd "$(dirname "$0")/.." || exit 1

fail=0
for spec in "$tests_dir"/*_spec.lua; do
  [ -e "$spec" ] || continue
  log=$(mktemp)
  timeout 120 nvim --headless -u "$tests_dir/minimal_init.lua" -l "$spec" >"$log" 2>&1
  rc=$?
  if [ "$rc" -ne 0 ] || grep -q '^FAIL:' "$log" || grep -qE '^E[0-9]{3,4}:' "$log"; then
    fail=1
    printf 'FAIL  %s\n' "$spec"
    grep -E '^FAIL:|^E[0-9]{3,4}:' "$log" | head -5 | sed 's/^/        /'
  else
    printf 'ok    %s\n' "$spec"
  fi
  rm -f "$log"
done

if [ "$fail" -eq 0 ]; then
  echo
  echo "all specs green"
fi
exit "$fail"
