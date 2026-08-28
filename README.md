# omarchy

My [Omarchy](https://omarchy.org) 4.x configuration — Hyprland settings, shell
(bar/lock) layout, and the small scripts that go with them.

Omarchy keeps its own defaults in `/usr/share/omarchy` and reads user overrides
from `~/.config/hypr` and `~/.config/omarchy`, so nothing here forks Omarchy.
These are the files that sit on top of it, which means package updates keep
improving the defaults underneath.

## What's actually customised

Most files in this repo are Omarchy's stock scaffolding, kept so a fresh machine
lands in a known state. The parts that differ from the defaults:

| File | Change |
| --- | --- |
| `config/hypr/input.lua` | `us,no` keyboard layouts, Left Alt + Left Shift to toggle |
| `config/hypr/autostart.lua` | Launches the keyboard-layout watcher below |
| `config/hypr/monitors.lua` | HiDPI: `GDK_SCALE` and monitor scale both at 2 |
| `config/omarchy/shell.json` | Bar on the bottom, transparent; keyboard-layout and weather widgets; lock-explorer plugin replacing `omarchy.lock` |
| `config/omarchy/shell.toml` | Base font size 9 |
| `config/omarchy/branding/` | Custom about + screensaver ASCII art |
| `config/omarchy/defaults/agent` | Default agent set to `claude` |
| `themes/aether/` | Custom theme — neon palette on near-black, Yaru-purple icons |
| `local/bin/omarchy-restore-lock-keyboard-layout` | Keeps the active keyboard layout across the lock screen |

The layout watcher exists because `omarchy-system-lock` runs
`hyprctl switchxkblayout all 0` on every lock, which drops the lock screen back
to US no matter what you were typing a second earlier. It is also packaged
standalone, with the reasoning written up, at
[omarchy-norwegian-keyboard](https://github.com/tommie0079/omarchy-norwegian-keyboard).

## Install

```bash
git clone https://github.com/tommie0079/omarchy.git
cd omarchy
./install.sh
```

It archives your current `~/.config/hypr` and `~/.config/omarchy` to
`~/.local/state/omarchy-dotfiles/` before writing anything, then copies the
config into place, installs the watcher into `~/.local/bin`, clones the
third-party shell plugins, and reloads Hyprland. It prints the exact `tar`
command to undo itself when it finishes.

Files are copied over the existing directories rather than replacing them, so
anything else living in those directories survives.

Flags:

| Flag | Effect |
| --- | --- |
| `--yes`, `-y` | Skip the confirmation prompt |
| `--no-plugins` | Don't clone the third-party shell plugins |

Log out and back in afterwards — the bar reads `shell.json` and loads plugins at
startup, so `hyprctl reload` alone won't pick those up.

## Rolling back

Every run leaves a timestamped archive, oldest first:

```bash
ls ~/.local/state/omarchy-dotfiles/
tar xzf ~/.local/state/omarchy-dotfiles/backup-<timestamp>-00.tar.gz -C ~/.config
hyprctl reload
```

The very first archive is the one holding your pristine pre-install config.

## Not included

**Third-party shell plugins.** `shell.json` references two plugins that belong
to other people, with their own licenses and release cadence, so they are cloned
rather than vendored:

- [SirJul1337/omarchy-lock-explorer](https://github.com/SirJul1337/omarchy-lock-explorer) — the lock screen, replacing `omarchy.lock`
- [weedwhitesandwine/plug](https://github.com/weedwhitesandwine/plug) — bar widget

## The theme

`themes/aether/` is my own theme: a near-black background (`#00000B`) under a
high-contrast yellow foreground (`#ECE500`), with a blue-violet accent
(`#5574e5`) and Yaru-purple icons. The palette was generated with
[Aether](https://archlinux.org/packages/?q=aether) from the wallpaper, so the
colours and the background agree with each other by construction.

Apply it after installing:

```bash
omarchy theme set aether
```

How it installs depends on the machine:

- **With Aether installed**, `~/.config/omarchy/themes/aether` is symlinked to
  `~/.config/aether/theme`, so regenerating the theme takes effect immediately.
- **Without Aether**, the copy in this repo is installed directly. The theme
  works fully; it just won't regenerate.

To use your own wallpaper, drop an image in
`~/.config/omarchy/themes/aether/backgrounds/` and run `omarchy theme set aether`
again. Regenerating the palette from a new image is `aether`'s job, not this
repo's.

## Requirements

Omarchy 4.x, whose Hyprland config is Lua (`~/.config/hypr/*.lua`). Omarchy 3.x
used `.conf` files and will not read any of this.

## License

[MIT](LICENSE), covering the configuration, scripts and colour palette.

The Lønningsburger name and the neon logo in `themes/aether/backgrounds/` are my
trademarks. The MIT licence grants copyright permissions, not trademark rights —
so reuse the theme freely, but swap the wallpaper for your own rather than
shipping the mark as your own branding.
