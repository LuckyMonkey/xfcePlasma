# Operations

## Restore Desktop After a Game

```bash
~/.local/bin/start-transparent-xfdesktop-session
```

This starts Picom effects, restarts the selected background session, sets XFCE desktop icon mode, enables transparent desktop background, and launches the custom transparent `xfdesktop` runtime.

Inspect or control the common lifecycle with:

```bash
xfce-plasma-background status
xfce-plasma-background restart
xfce-plasma-background fallback
```

## Game Guard Logs

During a game, `game-mode-raster-wallpaper` keeps a dark, low-saturation capture under the desktop icons. On exit it fades that static image to black before the native renderer returns.

```bash
tail -f ~/.local/state/xfce-plasma/logs/game-mode-guard.log
cat ~/.local/state/xfce-plasma/logs/game-mode-desktop-restore.log
```

## Game Detection

Edit:

```text
~/.config/game-mode-guard/patterns
```

One extended regular expression per line. Matching any process enters game mode.

## Autostart

Autostart entries are installed into:

```text
~/.config/autostart/
```

The main Picom autostart uses `systemd-run --user --unit=picom-effects --collect` so it is easy to restart and inspect.

## Rollback

Stop custom desktop and restore packaged xfdesktop:

```bash
~/.local/bin/restore-packaged-xfdesktop
xfconf-query -c xfwm4 -p /general/use_compositing -s true
pkill -x xwinwrap 2>/dev/null || true
```
