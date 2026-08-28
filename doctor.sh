#!/bin/bash

# Read-only. Reports how the aether theme is installed and where Omarchy is
# actually reading its background from. Changes nothing.

hdr() { printf '\n\033[1;34m== %s\033[0m\n' "$1"; }

hdr "Omarchy"
cat /usr/share/omarchy/version 2>/dev/null || echo "(no version file)"

hdr "Installed theme  ~/.config/omarchy/themes/aether"
if [[ -L ~/.config/omarchy/themes/aether ]]; then
  echo "SYMLINK -> $(readlink ~/.config/omarchy/themes/aether)"
  echo "  (a symlink means this machine is following its own Aether output,"
  echo "   not the theme from this repo)"
elif [[ -d ~/.config/omarchy/themes/aether ]]; then
  echo "directory (the repo's own copy -- expected)"
else
  echo "MISSING -- the theme is not installed"
fi
ls -l ~/.config/omarchy/themes/aether/backgrounds/ 2>&1 | tail -n +1
echo "palette accent: $(grep -m1 '^accent' ~/.config/omarchy/themes/aether/colors.toml 2>/dev/null || echo '(no colors.toml)')"
echo "  expected:     accent = \"#5574e5\""

hdr "Active theme"
echo "name: $(cat ~/.local/state/omarchy/current/theme.name 2>/dev/null || echo '(none)')"
echo "staged backgrounds (Omarchy picks the wallpaper from here):"
ls -l ~/.local/state/omarchy/current/theme/backgrounds/ 2>&1

hdr "Current background link"
ls -l ~/.local/state/omarchy/current/background 2>&1
target=$(readlink -f ~/.local/state/omarchy/current/background 2>/dev/null)
if [[ -f $target ]]; then
  echo "OK: resolves to an existing file, $(stat -c %s "$target") bytes"
else
  echo "BROKEN: resolves to '${target:-<nothing>}' which is not a file"
fi

hdr "Other places a background could come from"
ls -l ~/.config/omarchy/backgrounds/aether/ 2>&1
echo "Aether on this machine:"; ls -ld ~/.config/aether/theme 2>&1

hdr "This clone"
git -C "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)" log --oneline -3 2>&1

hdr "Shell process"
pgrep -a quickshell 2>/dev/null | head -3 || echo "(no quickshell process found)"
