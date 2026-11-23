#!/usr/bin/env bash
# Based on https://github.com/anshifmonz
set -Eeuo pipefail

PICKER_PID=""
SLURP_TIMEOUT=10
DEPS=(grim slurp magick tesseract wl-copy timeout hyprpicker rofi)

die() { echo "Error: $*" >&2; exit 1; }
safe_kill() { [[ -n "${1:-}" ]] && kill "$1" 2>/dev/null || true; }
cleanup() { safe_kill "$PICKER_PID"; }
trap cleanup EXIT INT TERM

for dep in "${DEPS[@]}"; do
  command -v "$dep" >/dev/null 2>&1 || die "Missing dependency: $dep"
done

OCR_LANGUAGE_LIST="$(pacman -Qq 2>/dev/null | grep -iE 'tesseract-(ocr|data|langpack)*-' | awk -F '-' '{print $NF}' | grep -v '^osd$' || true)"
OCR_LANGUAGE="${OCR_LANGUAGE:-}"
if [[ "$(printf '%s\n' "$OCR_LANGUAGE_LIST" | grep -c .)" -gt 1 ]]; then
  OCR_LANGUAGE=$(printf '%s\n' "$OCR_LANGUAGE_LIST" | rofi -dmenu -p "Select the OCR language")
  sleep 0.5 || true
fi
[[ -z "$OCR_LANGUAGE" ]] && OCR_LANGUAGE="eng"

hyprpicker -r -z &
PICKER_PID=$!
sleep 0.1 || true

REGION=$(timeout "$SLURP_TIMEOUT" slurp -b "#00000080" -c "#888888ff" -w 1) || die "No region selected (timeout or cancelled)"
[[ -z "$REGION" ]] && die "No region selected"
cleanup

grim -g "$REGION" - \
  | magick - -colorspace Gray -normalize -contrast-stretch 2% -sharpen 0x1.0 -resize 200% png:- \
  | tesseract - stdout -l "$OCR_LANGUAGE" --psm 6 \
  | wl-copy \
  || die "Failed to capture or process text"
