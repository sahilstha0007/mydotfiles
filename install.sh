#!/usr/bin/env bash
# =============================================================================
# mydotfiles — Universal Terminal Stack & VSCode Installer for Linux
# Portable, self-contained, and dependency-free.
#
# Links tracked configs into ~/.config:
#   - Neovim      (~/.config/nvim)
#   - Tmux        (~/.config/tmux)
#   - WezTerm     (~/.config/wezterm)
#   - VS Code     (~/.config/Code/User, Code - OSS, VSCodium)
#
# Automatically backs up any existing non-symlink directories into
# ~/.config-backup-<timestamp>/ before linking.
# =============================================================================
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
backup="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"
backed_up=0

echo "==> Deploying portable dotfiles from $repo..."

# 1. Standard config directories (~/.config/<name>)
mkdir -p "$HOME/.config"
for name in nvim tmux wezterm; do
  src="$repo/.config/$name"
  dst="$HOME/.config/$name"

  if [ ! -d "$src" ]; then
    echo "  [SKIP] $name: $src is missing" >&2
    continue
  fi

  if [ -L "$dst" ] && [ "$(readlink -f "$dst")" = "$(readlink -f "$src")" ]; then
    echo "  [OK]   $dst is already linked"
    continue
  fi

  if [ -L "$dst" ]; then
    # Already a symlink pointing elsewhere or broken — update cleanly
    rm -f "$dst"
  elif [ -e "$dst" ]; then
    mkdir -p "$backup"
    mv "$dst" "$backup/$name"
    echo "  [BACKUP] $dst -> $backup/$name"
    backed_up=1
  fi

  ln -s "$src" "$dst"
  echo "  [LINK]   $dst -> $src"
done

# 2. VS Code / Code - OSS / VSCodium User Configuration
code_src="$repo/.config/Code/User"
if [ -d "$code_src" ]; then
  # Support standard VSCode, Code - OSS, and VSCodium paths on Linux
  candidate_dirs=(
    "$HOME/.config/Code/User"
    "$HOME/.config/Code - OSS/User"
    "$HOME/.config/VSCodium/User"
  )

  # Always link to Code/User by default
  target_dirs=("$HOME/.config/Code/User")

  # Also link to other variants if their parent directories exist
  for variant in "$HOME/.config/Code - OSS" "$HOME/.config/VSCodium"; do
    if [ -d "$variant" ]; then
      target_dirs+=("$variant/User")
    fi
  done

  for user_dir in "${target_dirs[@]}"; do
    mkdir -p "$user_dir"
    for file in settings.json keybindings.json; do
      src_file="$code_src/$file"
      dst_file="$user_dir/$file"

      if [ -f "$src_file" ]; then
        if [ -L "$dst_file" ] && [ "$(readlink -f "$dst_file")" = "$(readlink -f "$src_file")" ]; then
          echo "  [OK]     $dst_file is already linked"
          continue
        fi

        if [ -L "$dst_file" ]; then
          rm -f "$dst_file"
        elif [ -e "$dst_file" ]; then
          mkdir -p "$backup/Code/User"
          mv "$dst_file" "$backup/Code/User/$file"
          echo "  [BACKUP] $dst_file -> $backup/Code/User/$file"
          backed_up=1
        fi
        ln -s "$src_file" "$dst_file"
        echo "  [LINK]   $dst_file -> $src_file"
      fi
    done
  done
fi

# 3. Ensure executable permissions on all shell scripts
echo "==> Setting executable permissions on scripts..."
find "$repo/.config" -type f -name "*.sh" -exec chmod +x {} + 2>/dev/null || true
find "$repo/.config" -type f -name "*.py" -exec chmod +x {} + 2>/dev/null || true

# 4. Tmux Plugin Manager (TPM) reminder
if [ ! -d "$HOME/.tmux/plugins/tpm" ] && [ ! -d "$repo/.config/tmux/plugins/tpm" ]; then
  echo ""
  echo "  [NOTE] Tmux Plugin Manager (TPM) not found."
  echo "         To clone: git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm"
  echo "         Then inside tmux press Prefix + I (Ctrl+a then I) to install plugins."
fi

# 5. VS Code extensions reminder
if command -v code >/dev/null 2>&1 && [ -f "$code_src/extensions.txt" ]; then
  echo ""
  echo "  [TIP]  To install tracked VS Code extensions on this machine, run:"
  echo "         xargs -n 1 code --install-extension < $code_src/extensions.txt"
fi

echo ""
if [ "$backed_up" -eq 1 ]; then
  echo "==> Done. Existing configs were safely archived in: $backup"
else
  echo "==> Done. All configurations linked cleanly."
fi
