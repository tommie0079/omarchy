#!/bin/bash

# Applies this Omarchy configuration to the current machine.
#
# Everything it writes lives under ~/.config/hypr, ~/.config/omarchy and
# ~/.local/bin. Both config directories are archived first, so a bad result is
# one tar command away from being undone.
#
#   ./install.sh              interactive
#   ./install.sh --yes        no confirmation prompt
#   ./install.sh --no-plugins skip cloning the third-party shell plugins

set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}"
bin_dir="$HOME/.local/bin"
backup_dir="$HOME/.local/state/omarchy-dotfiles"
stamp=$(date +%Y%m%d%H%M%S)

assume_yes=0
want_plugins=1
for arg in "$@"; do
  case $arg in
    --yes | -y) assume_yes=1 ;;
    --no-plugins) want_plugins=0 ;;
    *) printf 'Unknown option: %s\n' "$arg" >&2; exit 2 ;;
  esac
done

info() { printf '\033[1;32m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m==>\033[0m %s\n' "$1" >&2; }
die() { printf '\033[1;31m==>\033[0m %s\n' "$1" >&2; exit 1; }

# --- preflight ---------------------------------------------------------------

command -v hyprctl >/dev/null || die "hyprctl not found. This is an Omarchy/Hyprland config."

[[ -d $config_dir/hypr ]] ||
  die "$config_dir/hypr does not exist. Install Omarchy first, then run this to
    layer these settings on top of it."

if [[ ! -f $config_dir/hypr/hyprland.lua ]]; then
  warn "$config_dir/hypr has no hyprland.lua. This config targets Omarchy 4.x, which
    uses Lua; Omarchy 3.x used .conf files and will not read these files."
fi

if [[ $assume_yes -eq 0 ]]; then
  cat <<PROMPT
This will overwrite files in:

  $config_dir/hypr
  $config_dir/omarchy
  $bin_dir

Both config directories will be archived to $backup_dir first.

PROMPT
  read -rp "Continue? [y/N] " reply
  [[ $reply =~ ^[Yy] ]] || die "Aborted."
fi

# --- back up -----------------------------------------------------------------

mkdir -p "$backup_dir"

# Never overwrite an existing archive. Two runs in the same second would
# otherwise collide, and the second one would bury the pristine config that the
# first one saved -- exactly the copy worth keeping.
# Every archive carries a zero-padded counter, so `ls` sorts them oldest-first
# even when several land in the same second.
attempt=0
backup=$(printf '%s/backup-%s-%02d.tar.gz' "$backup_dir" "$stamp" "$attempt")
while [[ -e $backup ]]; do
  # Not ((attempt++)): that evaluates to 0 on the first pass, which is a false
  # arithmetic result, and set -e would abort the whole install.
  attempt=$((attempt + 1))
  backup=$(printf '%s/backup-%s-%02d.tar.gz' "$backup_dir" "$stamp" "$attempt")
done

tar czf "$backup" -C "$config_dir" hypr omarchy 2>/dev/null ||
  tar czf "$backup" -C "$config_dir" hypr
info "Archived your current config to $backup"

# --- copy config -------------------------------------------------------------

# cp -a over the tree rather than replacing it, so anything Omarchy or another
# tool has put in these directories survives.
cp -a "$repo_dir/config/hypr/." "$config_dir/hypr/"
info "Installed $config_dir/hypr"

mkdir -p "$config_dir/omarchy"
cp -a "$repo_dir/config/omarchy/." "$config_dir/omarchy/"
info "Installed $config_dir/omarchy"

mkdir -p "$bin_dir"
install -m 755 "$repo_dir/local/bin/omarchy-restore-lock-keyboard-layout" "$bin_dir/"
info "Installed $bin_dir/omarchy-restore-lock-keyboard-layout"

# --- third-party shell plugins -----------------------------------------------

# Not vendored: they are other people's repos, with their own licenses and
# release cadence. shell.json references them, so clone them or the bar loses
# those two widgets.
declare -A plugins=(
  [io.github.sirjul1337.lock-explorer]=https://github.com/SirJul1337/omarchy-lock-explorer.git
  [io.github.weedwhitesandwine.plug]=https://github.com/weedwhitesandwine/plug.git
)

if [[ $want_plugins -eq 1 ]]; then
  mkdir -p "$config_dir/omarchy/plugins"
  for id in "${!plugins[@]}"; do
    target="$config_dir/omarchy/plugins/$id"
    if [[ -d $target/.git ]]; then
      info "Plugin $id already cloned."
    elif git clone -q --depth 1 "${plugins[$id]}" "$target" 2>/dev/null; then
      info "Cloned $id"
    else
      warn "Could not clone $id from ${plugins[$id]}. The bar will start without it."
    fi
  done
else
  info "Skipped the third-party plugins (--no-plugins)."
fi

# --- theme symlink -----------------------------------------------------------

# Points at a generated theme directory, so it is only worth linking when that
# directory actually exists on this machine.
if [[ -d $config_dir/aether/theme ]]; then
  ln -sfn "$config_dir/aether/theme" "$config_dir/omarchy/themes/aether"
  info "Linked the aether theme."
fi

# --- apply -------------------------------------------------------------------

if hyprctl version >/dev/null 2>&1; then
  hyprctl reload >/dev/null && info "Reloaded Hyprland."
  pkill -f omarchy-restore-lock-keyboard-layout 2>/dev/null || true
  setsid "$bin_dir/omarchy-restore-lock-keyboard-layout" >/dev/null 2>&1 &
  disown
  info "Started the keyboard-layout watcher."
  warn "Log out and back in to pick up shell.json and the plugins -- the bar reads
    those at startup."
else
  warn "No running Hyprland session. Log in to apply."
fi

cat <<DONE

Done. To roll back:

  tar xzf $backup -C $config_dir
DONE
