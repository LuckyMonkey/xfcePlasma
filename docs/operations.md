# Operations

## Restore Desktop After a Game

```bash
~/.local/bin/start-transparent-xfdesktop-session
```

This starts Picom effects, restarts the tie-dye wallpaper service, sets XFCE desktop icon mode, enables transparent desktop background, and launches the custom transparent `xfdesktop` runtime.

## Game Guard Logs

```bash
tail -f /tmp/game-mode-guard.log
cat /tmp/game-mode-desktop-restore.log
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
