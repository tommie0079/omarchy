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
#   ./install.sh --no-theme   install the theme but leave the active one alone
#   ./install.sh --link-aether follow this machine's Aether output instead of the
#                             vendored theme (for the machine that generates it)

set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}"
bin_dir="$HOME/.local/bin"
backup_dir="$HOME/.local/state/omarchy-dotfiles"
stamp=$(date +%Y%m%d%H%M%S)

assume_yes=0
want_plugins=1
want_theme=1
link_aether=0
for arg in "$@"; do
  case $arg in
    --yes | -y) assume_yes=1 ;;
    --no-plugins) want_plugins=0 ;;
    --no-theme) want_theme=0 ;;
    --link-aether) link_aether=1 ;;
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

# Never overwrite an existing archive: two runs in the same second would collide,
# and the second would bury the pristine config the first one saved -- exactly
# the copy worth keeping. The zero-padded counter also keeps `ls` in
# oldest-first order when several land in the same second.
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

# --- theme -------------------------------------------------------------------

# Install the vendored copy by default: reproducing the theme as published is
# what this repo is for. Following ~/.config/aether/theme instead only makes
# sense on the machine whose Aether generates it -- anywhere else that directory
# holds a different palette and none of these backgrounds, so linking to it
# silently substitutes another theme and the wallpaper never appears.
mkdir -p "$config_dir/omarchy/themes"
theme_target="$config_dir/omarchy/themes/aether"

if [[ $link_aether -eq 1 && ! -d $config_dir/aether/theme ]]; then
  warn "--link-aether given but $config_dir/aether/theme does not exist.
    Installing the vendored theme instead."
  link_aether=0
fi

if [[ $link_aether -eq 1 ]]; then
  rm -rf "$theme_target"
  ln -sfn "$config_dir/aether/theme" "$theme_target"
  info "Linked the aether theme to Aether's generated output."
else
  # A leftover symlink would make cp write through it into Aether's directory.
  if [[ -L $theme_target ]]; then
    rm -f "$theme_target"
  fi
  mkdir -p "$theme_target"
  cp -a "$repo_dir/themes/aether/." "$theme_target/"
  info "Installed the aether theme."
fi

# --- apply -------------------------------------------------------------------

session_running=0
hyprctl version >/dev/null 2>&1 && session_running=1

if [[ $session_running -eq 1 ]]; then
  hyprctl reload >/dev/null && info "Reloaded Hyprland."
  pkill -f omarchy-restore-lock-keyboard-layout 2>/dev/null || true
  setsid "$bin_dir/omarchy-restore-lock-keyboard-layout" >/dev/null 2>&1 &
  disown
  info "Started the keyboard-layout watcher."
else
  warn "No running Hyprland session. Log in to apply."
fi

# Installing the theme only puts it on the menu; without applying it the machine
# keeps whatever theme was already active, and the install looks like it did
# nothing to the background and the colours.
#
# Applying one talks to the running shell, so it needs a session: with no
# compositor omarchy-theme-set blocks indefinitely rather than failing, which
# would hang this script. The timeout is the backstop for a session that is
# present but wedged.
if [[ $want_theme -eq 0 ]]; then
  info "Left the active theme alone (--no-theme). Apply it with: omarchy theme set aether"
elif ! command -v omarchy-theme-set >/dev/null; then
  warn "omarchy-theme-set not found. Apply the theme yourself: omarchy theme set aether"
elif [[ $session_running -eq 0 ]]; then
  warn "The theme is installed but not applied -- that needs a running session.
    Once you have logged in, run: omarchy theme set aether"
elif timeout 120 omarchy-theme-set aether >/dev/null 2>&1; then
  info "Applied the aether theme."
else
  warn "Could not apply the aether theme. It is installed, so this should work
    once you are logged in: omarchy theme set aether"
fi

if [[ $session_running -eq 1 ]]; then
  warn "Log out and back in to pick up shell.json and the plugins -- the bar reads
    those at startup."
fi

cat <<DONE

Done. To roll back:

  tar xzf $backup -C $config_dir
DONE
