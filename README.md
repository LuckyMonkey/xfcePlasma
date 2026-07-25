# xfcePlasma

Animated XFCE desktop stack for an Xubuntu/XFCE session on X11.

This repo packages the working animated background setup from `/home/freezer`:

- transparent custom `xfdesktop` runtime so desktop icons remain visible over animation
- GPU tie-dye wallpaper renderer running under `xwinwrap`
- Picom v13 compositor with window animations while XFWM remains the window manager
- dual-monitor wallpaper sync helper
- game-aware guard that disables Picom/compositing while games run, then restores the desktop stack after exit
- fade-to/from-black helper for smoother game transitions

This is **not PipCast**. PipCast lives elsewhere and is intentionally excluded.

## Layout

```text
bin/                         helper scripts installed to ~/.local/bin
runtime/tie-dye-wallpaper/   animated wallpaper binary and shader
runtime/xfdesktop-transparent/ custom transparent xfdesktop runtime
runtime/picom-v13            Picom v13 binary currently in use
config/picom/picom.conf      compositor/animation config
config/game-mode-guard/      process patterns for game detection
config/xfce4/                XFCE keyboard shortcut backup
autostart/                   XFCE autostart desktop entries
systemd/user/                user services
docs/                        operational notes
```

## Install

From the repo root:

```bash
./install.sh
```

Then reload/restart the session pieces:

```bash
systemctl --user daemon-reload
systemctl --user enable --now game-mode-guard.service
systemctl --user restart tie-dye-wallpaper-mvp.service
~/.local/bin/start-transparent-xfdesktop-session
```

The installer copies files into the current user's home directory. It rewrites `/home/freezer` paths in text scripts/configs to the target `$HOME` where practical.

## Runtime Model

XFWM remains the window manager. XFWM's compositor is disabled and Picom v13 provides compositing/window animation.

The background animation is rendered by:

```text
xwinwrap -> tie-dye-wallpaper -> shader.fs
```

A patched/custom `xfdesktop` provides the desktop icon layer with transparent background. The animation shows through, but XFCE desktop icons remain available.

## Game Mode

`game-mode-guard` watches process patterns in:

```text
~/.config/game-mode-guard/patterns
```

When a game starts:

1. waits a launch grace period
2. fades out
3. stops Picom
4. disables XFWM compositing

When the game exits:

1. waits an exit grace period
2. restarts the transparent desktop stack
3. fades back in

The guard is intentionally generic; it is not tied to Cyberpunk or any one game.

## Important Commands

Start/restore the full stack:

```bash
~/.local/bin/start-transparent-xfdesktop-session
```

Stop wallpaper animation:

```bash
~/.local/bin/stop-animated-wallpaper
```

Emergency shortcut:

```text
Ctrl+Alt+Shift+F12 -> ~/.local/bin/stop-animated-wallpaper
```

Restart Picom effects:

```bash
systemd-run --user --unit=picom-effects --collect ~/.local/bin/start-picom-effects
```

Check game guard:

```bash
systemctl --user status game-mode-guard.service --no-pager
journalctl --user -u game-mode-guard.service -f
```

## Notes

This is designed for X11. Wayland behavior is not expected to match because `xwinwrap`, `ximagesrc`-style assumptions, and root-window compositing differ.

The included binaries are the known-good local runtime binaries. Rebuilding from source is possible but not captured as the primary path in this repo yet.
