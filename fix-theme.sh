#!/bin/bash

# Applies the aether theme and reports what happened, so a machine where the
# wallpaper does not appear can be diagnosed from facts.
#
# Writes everything to ~/doctor2.txt as well as printing it. Deliberately does
# not use `set -e`: a failing step is the information worth capturing.

out="$HOME/doctor2.txt"

{
  echo "--- applying ---"
  omarchy theme set aether
  echo "exit=$?"

  echo "--- active theme ---"
  cat ~/.local/state/omarchy/current/theme.name 2>&1

  echo "--- background link ---"
  readlink ~/.local/state/omarchy/current/background 2>&1

  echo "--- installed theme ---"
  ls -la ~/.config/omarchy/themes/aether/ 2>&1

  echo "--- its backgrounds ---"
  ls -la ~/.config/omarchy/themes/aether/backgrounds/ 2>&1

  echo "--- staged backgrounds (what Omarchy renders from) ---"
  ls -la ~/.local/state/omarchy/current/theme/backgrounds/ 2>&1
} 2>&1 | tee "$out"

echo
echo "Saved to $out"
