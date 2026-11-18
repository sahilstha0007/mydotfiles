#!/usr/bin/env bash
# =============================================================================
# mydotfiles — Universal Terminal Stack & VSCode Installer for Linux
# Portable, self-contained, and dependency-free.
#
# Links tracked configs into ~/.config:
#   - Neovim      (~/.config/nvim)
#   - Tmux        (~/.config/tmux)
#   - WezTerm     (~/.config/wezterm)
#   - Kitty Dev   (~/.config/kitty)
#   - Oh-My-Posh  (~/.config/ohmyposh)
#   - Bat         (~/.config/bat)
#   - Yazi        (~/.config/yazi)
#   - LazyGit     (~/.config/lazygit)
#   - LazyDocker  (~/.config/lazydocker)
#   - Btop        (~/.config/btop)
#   - Fastfetch   (~/.config/fastfetch)
#   - Atuin       (~/.config/atuin)
#   - VS Code     (~/.config/Code/User, Code - OSS, VSCodium)
#
# Automatically backs up any existing non-symlink directories into
# ~/.config-backup-<timestamp>/ before linking.
# =============================================================================
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

run_doctor() {
  local strict=0
  [ "${1:-}" = "--strict" ] && strict=1

  local repo_fail=0 unmanaged_warn=0
  local canonical_repo
  canonical_repo="$(readlink -f "$repo")"

  echo "==> Running dotfiles symlink and permission doctor..."

  # 1. Verify every repo-managed symlink target exists and resolves into $repo
  for name in nvim tmux wezterm kitty ohmyposh bat yazi lazygit lazydocker btop fastfetch atuin; do
    local src="$repo/.config/$name" dst="$HOME/.config/$name"
    [ -d "$src" ] || continue
    if [ ! -L "$dst" ] || [ ! -e "$dst" ] || [ "$(readlink -f "$dst" 2>/dev/null || true)" != "$(readlink -f "$src")" ]; then
      echo "  [FAIL]   broken or unlinked repo config: $dst -> $(readlink "$dst" 2>/dev/null || echo 'missing')" >&2
      repo_fail=1
    fi
  done

  for pair in "zshrc:.zshrc" "bashrc_custom:.bashrc_custom" "zshenv:.zshenv"; do
    local src="$repo/shell/${pair%%:*}" dst="$HOME/${pair##*:}"
    [ -f "$src" ] || continue
    if [ ! -L "$dst" ] || [ ! -e "$dst" ] || [ "$(readlink -f "$dst" 2>/dev/null || true)" != "$(readlink -f "$src")" ]; then
      echo "  [FAIL]   broken or unlinked shell file: $dst -> $(readlink "$dst" 2>/dev/null || echo 'missing')" >&2
      repo_fail=1
    fi
  done

  if [ -d "$repo/bin" ]; then
    for src_file in "$repo/bin"/*; do
      [ -f "$src_file" ] || continue
      local bname dst_file
      bname="$(basename "$src_file")"
      dst_file="$HOME/.local/bin/$bname"
      if [ ! -L "$dst_file" ] || [ ! -e "$dst_file" ] || [ "$(readlink -f "$dst_file" 2>/dev/null || true)" != "$(readlink -f "$src_file")" ]; then
        echo "  [FAIL]   broken or unlinked repo bin: $dst_file -> $(readlink "$dst_file" 2>/dev/null || echo 'missing')" >&2
        repo_fail=1
      elif [ ! -x "$src_file" ]; then
        echo "  [FAIL]   repo bin lacks +x: $src_file" >&2
        repo_fail=1
      fi
    done
  fi

  # Check repo script permissions inside .config/
  while IFS= read -r -d '' rscript; do
    if [ ! -x "$rscript" ]; then
      echo "  [FAIL]   repo script lacks +x: $rscript" >&2
      repo_fail=1
    fi
  done < <(find "$repo/.config" -type f \( -name "*.sh" -o -name "*.py" \) -print0 2>/dev/null || true)

  # 2. Scan ~/.config and ~/.local/bin for real dangling symlinks.
  # Browser/Electron/Mozilla runtime lock symlinks intentionally encode host/PID tokens as dangling targets:
  # SingletonLock, SingletonCookie, SingletonSocket, lock, lockfile, .parentlock are runtime artifacts, not defects.
  for scan_dir in "$HOME/.config" "$HOME/.local/bin"; do
    [ -d "$scan_dir" ] || continue
    while IFS= read -r -d '' link; do
      local base target resolved
      base="$(basename "$link")"
      case "$base" in
        SingletonLock|SingletonCookie|SingletonSocket|lock|lockfile|.parentlock)
          continue
          ;;
      esac
      target="$(readlink "$link" 2>/dev/null || true)"
      resolved="$(readlink -m "$link" 2>/dev/null || true)"
      if [[ "$target" == "$canonical_repo"* ]] || [[ "$resolved" == "$canonical_repo"* ]] || [[ "$target" == *"/mydotfiles/"* ]]; then
        echo "  [FAIL]   repo-managed dangling link: $link -> $target" >&2
        repo_fail=1
      elif [ "$scan_dir" = "$HOME/.local/bin" ] && [ -f "$repo/bin/$base" ]; then
        # Already reported in check 1 as broken repo bin
        continue
      elif [ "$scan_dir" = "$HOME/.config" ] && [ -d "$repo/.config/$base" ]; then
        # Already reported in check 1 as broken repo config
        continue
      else
        echo "  [WARN]   unmanaged dangling symlink: $link -> $target  (ask before: rm '$link')"
        unmanaged_warn=1
      fi
    done < <(find "$scan_dir" -xtype l -print0 2>/dev/null || true)
  done

  # 3. Report unmanaged non-executable files/scripts in ~/.local/bin (excluding *.env data files)
  if [ -d "$HOME/.local/bin" ]; then
    while IFS= read -r -d '' f; do
      [ -L "$f" ] && [ ! -e "$f" ] && continue # already reported as broken symlink above
      local fname resolved_f
      fname="$(basename "$f")"
      case "$fname" in
        *.env|*.txt|*.md|*.json) continue ;;
      esac
      resolved_f="$(readlink -f "$f" 2>/dev/null || printf '%s' "$f")"
      if [[ "$resolved_f" == "$canonical_repo/"* ]]; then
        echo "  [FAIL]   repo-owned bin lacks +x: $f -> $resolved_f" >&2
        repo_fail=1
      else
        echo "  [WARN]   unmanaged non-executable in ~/.local/bin: $f  (ask before: chmod +x '$f')"
        unmanaged_warn=1
      fi
    done < <(find "$HOME/.local/bin" -maxdepth 1 \( -type f -o -type l \) ! -executable -print0 2>/dev/null || true)
  fi

  if [ "$repo_fail" -ne 0 ]; then
    echo "==> Doctor FAILED: repo symlink or permission defect(s) detected." >&2
    return 1
  fi
  if [ "$strict" -eq 1 ] && [ "$unmanaged_warn" -ne 0 ]; then
    echo "==> Doctor FAILED (--strict): unmanaged dangling symlink(s) or non-executable file(s) found." >&2
    return 1
  fi
  echo "==> Doctor OK: repo symlinks intact (unmanaged warnings: $unmanaged_warn)"
  return 0
}

case "${1:-}" in
  -h|--help)
    cat <<'EOF'
Usage: install.sh [--doctor [--strict]] [--help]

  (default)        Link tracked dotfiles/bins, pre-warm shell/bat caches, backup collisions
  --doctor         Verify repo symlinks/exec bits and report unmanaged broken links (non-destructive)
  --doctor --strict  Exit non-zero if unmanaged broken symlinks or non-exec scripts remain
EOF
    exit 0
    ;;
  --doctor)
    shift
    if [ "${1:-}" = "--strict" ] && [ "$#" -eq 1 ]; then
      run_doctor --strict
      exit $?
    elif [ "$#" -eq 0 ]; then
      run_doctor
      exit $?
    else
      printf 'install.sh: unknown option for --doctor: %s\n' "$*" >&2
      exit 2
    fi
    ;;
  "") ;;
  *)
    printf 'install.sh: unknown option: %s\nUsage: install.sh [--doctor [--strict]] [--help]\n' "$1" >&2
    exit 2
    ;;
esac

backup="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"
backed_up=0

echo "==> Deploying portable dotfiles from $repo..."

# 1. Standard config directories (~/.config/<name>)
mkdir -p "$HOME/.config"
for name in nvim tmux wezterm kitty ohmyposh bat yazi lazygit lazydocker btop fastfetch atuin; do
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
    # Already a symlink pointing elsewhere or broken — update cleanly.
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

# 3. Shell Runtime Configurations (~/.zshrc, ~/.bashrc_custom, ~/.zshenv)
shell_src="$repo/shell"
if [ -d "$shell_src" ]; then
  declare -A shell_map=(
    ["zshrc"]="$HOME/.zshrc"
    ["bashrc_custom"]="$HOME/.bashrc_custom"
    ["zshenv"]="$HOME/.zshenv"
  )

  for file in "${!shell_map[@]}"; do
    src_file="$shell_src/$file"
    dst_file="${shell_map[$file]}"

    if [ -f "$src_file" ]; then
      if [ -L "$dst_file" ] && [ "$(readlink -f "$dst_file")" = "$(readlink -f "$src_file")" ]; then
        echo "  [OK]     $dst_file is already linked"
        continue
      fi

      if [ -L "$dst_file" ]; then
        rm -f "$dst_file"
      elif [ -e "$dst_file" ]; then
        mkdir -p "$backup/shell"
        mv "$dst_file" "$backup/shell/$file"
        echo "  [BACKUP] $dst_file -> $backup/shell/$file"
        backed_up=1
      fi

      ln -s "$src_file" "$dst_file"
      echo "  [LINK]   $dst_file -> $src_file"
    fi
  done
fi

# 4. CLI Binaries & Dispatchers (~/.local/bin)
bin_src="$repo/bin"
if [ -d "$bin_src" ]; then
  mkdir -p "$HOME/.local/bin"
  for src_file in "$bin_src"/*; do
    [ -f "$src_file" ] || continue
    name="$(basename "$src_file")"
    dst_file="$HOME/.local/bin/$name"

    if [ -L "$dst_file" ] && [ "$(readlink -f "$dst_file")" = "$(readlink -f "$src_file")" ]; then
      echo "  [OK]     $dst_file is already linked"
      continue
    fi

    if [ -L "$dst_file" ]; then
      rm -f "$dst_file"
    elif [ -e "$dst_file" ]; then
      mkdir -p "$backup/bin"
      mv "$dst_file" "$backup/bin/$name"
      echo "  [BACKUP] $dst_file -> $backup/bin/$name"
      backed_up=1
    fi

    chmod +x "$src_file"
    ln -s "$src_file" "$dst_file"
    echo "  [LINK]   $dst_file -> $src_file"
  done
fi

# 5. Ensure gitignored generated theme includes exist on a fresh clone
if [ ! -f "$repo/.config/btop/themes/matugen.theme" ] && [ -f "$repo/.config/btop/themes/nightfox.theme" ]; then
  cp "$repo/.config/btop/themes/nightfox.theme" "$repo/.config/btop/themes/matugen.theme"
  echo "  [INIT]   $repo/.config/btop/themes/matugen.theme (from nightfox default)"
fi
tmux_tmp_dir="${TMUX_TMPDIR:-$HOME/.cache/tmux}"
mkdir -p "$tmux_tmp_dir" "$HOME/.cache/zsh-cache" "${XDG_STATE_HOME:-$HOME/.local/state}/nvim"
chmod 700 "$tmux_tmp_dir" 2>/dev/null || true

# 6. Ensure executable permissions on all shell scripts
echo "==> Setting executable permissions on scripts..."
find "$repo/.config" -type f -name "*.sh" -exec chmod +x {} + 2>/dev/null || true
find "$repo/.config" -type f -name "*.py" -exec chmod +x {} + 2>/dev/null || true
find "$repo/bin" -type f -exec chmod +x {} + 2>/dev/null || true

# 6b. Provision lazy.nvim (nvim's plugin manager) here — the single place allowed
#     to do network I/O. lazy-init.lua deliberately does NOT bootstrap at runtime.
#     Pinned to the stable release commit (annotated tag 'stable' = v11.17.5).
lazy_nvim_dir="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy/lazy.nvim"
if [ -d "$lazy_nvim_dir/.git" ]; then
  echo "  [OK]     lazy.nvim already installed at $lazy_nvim_dir"
elif [ -e "$lazy_nvim_dir" ]; then
  echo "  [WARN]   $lazy_nvim_dir exists but is not a git checkout — skipping (nvim may fail)" >&2
else
  echo "  [INSTALL] cloning pinned lazy.nvim -> $lazy_nvim_dir"
  mkdir -p "$(dirname "$lazy_nvim_dir")"
  if git clone --filter=blob:none --branch=stable https://github.com/folke/lazy.nvim.git "$lazy_nvim_dir" \
      && git -C "$lazy_nvim_dir" checkout --detach 85c7ff3711b730b4030d03144f6db6375044ae82; then
    echo "  [OK]     lazy.nvim pinned at $(git -C "$lazy_nvim_dir" rev-parse --short HEAD)"
  else
    echo "  [WARN]   lazy.nvim provision failed (offline?). Re-run install.sh with network to fix nvim." >&2
  fi
fi

# 7. Rebuild bat theme cache if bat is installed (idempotent: only rebuild if missing or older than themes)
if command -v bat >/dev/null 2>&1 && [ -d "$HOME/.config/bat/themes" ]; then
  bat_cache_bin="${XDG_CACHE_HOME:-$HOME/.cache}/bat/themes.bin"
  bat_need_rebuild=0
  if [ ! -s "$bat_cache_bin" ]; then
    bat_need_rebuild=1
  else
    for tf in "$HOME/.config/bat/themes"/*.tmTheme; do
      [ -e "$tf" ] && [ "$tf" -nt "$bat_cache_bin" ] && bat_need_rebuild=1 && break
    done
  fi
  if [ "$bat_need_rebuild" -eq 1 ]; then
    bat cache --build >/dev/null 2>&1 || true
    echo "  [WARM]   bat theme cache rebuilt"
  else
    echo "  [OK]     bat theme cache warm"
  fi
fi

# 7b. Pre-warm zsh init caches and compdump (D2) without sourcing secrets (~/.zshrc.local)
prewarm_zsh_tool() {
  local tool="$1" cache="$2" dep="$3"
  shift 3
  local bin_path
  bin_path="$(command -v "$tool" 2>/dev/null || true)"
  [ -n "$bin_path" ] || return 0
  if [ ! -s "$cache" ] || [ "$bin_path" -nt "$cache" ] || { [ -n "$dep" ] && [ -e "$dep" ] && [ "$dep" -nt "$cache" ]; }; then
    local tmp_c
    tmp_c="$(mktemp "${cache}.XXXXXX")"
    if "$@" > "$tmp_c" 2>/dev/null && [ -s "$tmp_c" ]; then
      mv -f "$tmp_c" "$cache"
      echo "  [WARM]   $cache"
      return 0
    fi
    rm -f "$tmp_c"
  fi
  return 0
}

prewarm_zsh_tool zoxide "$HOME/.cache/zsh-cache/zoxide.zsh" "" zoxide init zsh
prewarm_zsh_tool direnv "$HOME/.cache/zsh-cache/direnv.zsh" "" direnv hook zsh
prewarm_zsh_tool atuin  "$HOME/.cache/zsh-cache/atuin.zsh"  "" atuin init zsh
if command -v oh-my-posh >/dev/null 2>&1; then
  [ -f "$HOME/.config/ohmyposh/zen.toml" ] && \
    prewarm_zsh_tool oh-my-posh "$HOME/.cache/zsh-cache/omp-zen.zsh" "$HOME/.config/ohmyposh/zen.toml" \
      oh-my-posh init zsh --config "$HOME/.config/ohmyposh/zen.toml"
  [ -f "$HOME/.config/ohmyposh/zen.toml" ] && \
    prewarm_zsh_tool oh-my-posh "$HOME/.cache/zsh-cache/omp-fallback.zsh" "$HOME/.config/ohmyposh/zen.toml" \
      oh-my-posh init zsh --config "$HOME/.config/ohmyposh/zen.toml"
fi

if command -v zsh >/dev/null 2>&1; then
  zcomp_warm=$(zsh -fc '
    dump="$HOME/.zcompdump-${HOST}-${ZSH_VERSION}"
    omz_comp="$HOME/.oh-my-zsh/custom/plugins/zsh-completions/src"
    [ -d "$omz_comp" ] && fpath=("$omz_comp" $fpath)
    if [ ! -s "$dump" ] || { [ -d "$omz_comp" ] && [ "$omz_comp" -nt "$dump" ]; }; then
      autoload -Uz compinit
      zmodload -F zsh/files b:zf_mv 2>/dev/null && mv() { zf_mv "$@"; }
      compinit -u -d "$dump" >/dev/null 2>&1
      echo "WARMED:$dump"
    fi
  ' 2>/dev/null || true)
  case "$zcomp_warm" in
    WARMED:*) echo "  [WARM]   ${zcomp_warm#WARMED:}" ;;
  esac
fi
echo "  [OK]     shell caches warm"

# 7. Protect mydotfiles-managed paths from ML4W dotfiles installer updates
ml4w_installer_cfg="$HOME/.config/ml4w-dotfiles-installer"
if [ -d "$ml4w_installer_cfg" ]; then
  echo "==> Registering protected paths in ML4W installer blacklists..."
  protected_entries=(
    ".config/kitty"
    ".config/nvim"
    ".config/tmux"
    ".config/wezterm"
    ".config/ohmyposh"
    ".config/bat"
    ".config/yazi"
    ".config/lazygit"
    ".config/lazydocker"
    ".config/btop"
    ".config/fastfetch"
    ".config/atuin"
    ".config/matugen"
    ".zshrc"
    ".zshrc_custom"
    ".zshenv"
    ".bashrc_custom"
  )
  for profile_dir in "$ml4w_installer_cfg"/*/; do
    [ -d "$profile_dir" ] || continue
    bl="${profile_dir%/}/blacklist"
    touch "$bl"
    for entry in "${protected_entries[@]}"; do
      if ! grep -Fxq "$entry" "$bl"; then
        printf '%s\n' "$entry" >> "$bl"
      fi
    done
    echo "  [LOCKED] $bl"
  done
fi

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
