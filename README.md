# xfcePlasma

Animated XFCE desktop stack for an Xubuntu/XFCE session on X11.

This repo packages a portable animated background stack:

- transparent custom `xfdesktop` runtime so desktop icons remain visible over animation
- GPU tie-dye wallpaper renderer running under `xwinwrap`
- Picom v13 compositor with window animations while XFWM remains the window manager
- dual-monitor wallpaper sync helper
- game-aware guard that freezes a dark, desaturated XFCE wallpaper while games run and restores only the components it stopped
- raster fade-to-black handoff for smooth return to the animated renderer

This is **not PipCast**. PipCast lives elsewhere and is intentionally excluded.

## Layout

```text
bin/                         helper scripts installed to ~/.local/bin
runtime/tie-dye-wallpaper/   animated wallpaper binary, active shader, and shader presets
runtime/xfdesktop-transparent/ custom transparent xfdesktop runtime
runtime/picom-v13            Picom v13 binary currently in use
config/picom/picom.conf      compositor/animation config
config/game-mode-guard/      process patterns for game detection
config/xfce4/                XFCE keyboard shortcut backup
autostart/                   XFCE autostart desktop entries
systemd/user/                user services
docs/                        operational notes
```

## Dependencies

Runtime integration uses XFCE/X11, `systemd --user`, `xwinwrap`, `xdotool`, `xrandr`, `xfconf-query`, and ImageMagick (`import` and `convert`). Building requires a C11 compiler, raylib development files, GTK 3 development files, `pkg-config`, and `make`.

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

The installer resolves the current user and XDG paths at runtime. It does not rewrite author-specific paths or overwrite user-created shaders.

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
2. captures and darkens the current animation into per-monitor static XFCE wallpapers
3. stops the animated renderer and project Picom
4. disables XFWM compositing

When the game exits, the static raster fades to black, the previous XFCE wallpaper properties are restored, and the full-color renderer fades back in. Wallpaper, Picom, and XFWM states are restored only when they were active before the game.

The guard is intentionally generic; it is not tied to Cyberpunk or any one game.

## Important Commands

The panel includes all wallpaper profiles (including Ricky, Red Forest, and Boku City), a live GLSL source editor with create/import/remove controls, speed and safety controls, services, diagnostics, and editable XFCE shortcuts.

Open the single unified settings panel:

```bash
~/.local/bin/xfce-plasma-settings
```

Start/restore the full wallpaper plus desktop-icon stack:

```bash
~/.local/bin/start-animated-wallpaper-with-xfdesktop-icons
```

Switch animated wallpapers:

```bash
~/.local/bin/animated-wallpaper-picker next
~/.local/bin/animated-wallpaper-picker previous
```

Adjust speed live:

```bash
~/.local/bin/animated-wallpaper-speed up
~/.local/bin/animated-wallpaper-speed down
```

Stop wallpaper animation:

```bash
~/.local/bin/stop-animated-wallpaper
```

Wallpaper hotkeys:

```text
Ctrl+Alt+Shift+Left/Right -> previous/next wallpaper
Ctrl+Alt+Shift+Up/Down    -> slower/faster wallpaper speed
```

Edit shortcuts from the same panel or CLI:

```bash
~/.local/bin/xfce-plasma-settings shortcuts list
~/.local/bin/xfce-plasma-settings shortcuts set wallpaper-next "<Super>Right"
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

The renderer and unified GTK settings panel are built from `src/` with `make`. The matching known-good runtime artifacts are included for installation; bundled Picom and patched xfdesktop remain binary compatibility components pending their separate reproducibility work.
