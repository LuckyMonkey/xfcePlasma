# Phase 1 Audit (Historical)

> Archived on 2026-07-29. This document records the pre-hardening state and its
> recommendations; statements such as “source absent” describe that snapshot,
> not the current tree. See [README.md](../README.md) for the current
> architecture and [binary-provenance.md](binary-provenance.md) for the current
> source/artifact audit.

Date: 2026-07-25
Repository: `xfcePlasma`
Scope: repository files only. No live desktop installation under `~/.local`, `~/.config`, or the user systemd runtime was modified during this audit.

## Summary

`xfcePlasma` is currently a machine-captured XFCE/X11 animated desktop stack rather than a portable source-built project. It packages shell orchestration, one Python fade utility, editable GLSL artwork, and several precompiled ELF runtime artifacts. The author machine behavior is encoded through hardcoded `/home/freezer`, `freezer`, `/run/user/1000`, `DISPLAY=:0.0`, and monitor names.

The current live design inferred from repository files is:

- `xwinwrap` owns a desktop-sized child window.
- `runtime/tie-dye-wallpaper/tie-dye-wallpaper` renders `shader.fs` with raylib.
- Patched `xfdesktop` supplies transparent desktop icons.
- Picom v13 provides compositor effects while XFWM remains the window manager.
- `game-mode-guard` watches process regexes and fullscreen windows, then stops wallpaper/Picom and disables XFWM compositing while games run.

## Component Table

| component | language | persistent or one-shot | dependencies | current problems | proposed replacement |
|---|---:|---:|---|---|---|
| `install.sh` | Bash | one-shot installer | `bash`, `id`, `mkdir`, `sed`, `chmod`, `cp`, `rsync`, `find`, `systemctl` | Installs directly into current `$HOME`; uses broad `sed` replacement for `/home/freezer`, `USER=freezer`, `LOGNAME=freezer`, `/run/user/1000`; no dry-run, manifest, uninstall, dependency check, or confirmation around user config; copies private editable shaders and whole personal shortcut XML. | Rewrite as idempotent installer with `--check`, `--dry-run`, `--user`, `--prefix`, `--uninstall`, manifest, templates, XDG paths, optional private-art input. |
| `bin/animated-wallpaper-picker` | Bash | one-shot control utility | `bash`, `basename`, `sed`, `find`, `sort`, `cmp`, `sha256sum`, `awk`, `cp`, `systemctl`, `notify-send`, optional `zenity`/`rofi` | Uses `eval` for Zenity rows; cannot safely handle spaces; copies shader over `shader.fs`; restarts renderer and `xfdesktop`; writes `/tmp/animated-wallpaper-picker.log`; fixed shader order names private artwork. | Keep shell, remove `eval`, use atomic selected-shader state, support `set`, `user-add`, list/current/next/prev, signal or inotify renderer reload without `xfdesktop` restart. |
| `bin/animated-wallpaper-speed` | Bash | one-shot control utility | `bash`, `mkdir`, `cat`, `notify-send` | State under `~/.local/state/tie-dye-wallpaper`, not project XDG namespace; direct non-atomic writes; no numeric `set`; presets omit `fast`; no locking or validation. | Keep shell; use common library, atomic writes, bounded numeric validation, `get/set/up/down/freeze/restore`, renderer watches speed state. |
| `bin/dual-monitor-wallpaper-sync` | POSIX sh | persistent watcher | `sh`, `xfconf-query` | Hardcoded `monitorDP-0`, `monitorHDMI-0`, `screen0`, `workspace0`; only two monitors; no flags despite autostart; blocks forever on `xfconf-query -m`; no logging or dry-run. | Rename to `xfce-plasma-monitor-sync` with compatibility wrapper; discover outputs/properties dynamically; support `--once`, `--watch`, `--dry-run`. |
| `bin/game-mode-fade` | Python | one-shot GUI fade utility | `python3`, PyGObject `gi`, GTK 3, GDK, GLib, Cairo through GTK | Python runtime dependency; hardcoded display/session fallbacks; silently exits if GTK unavailable; imports unused `time`; draws fullscreen popup fade. | Replace with small C utility if retained for precise GTK/X11 fade timing, or shell-only if renderer-native fade fully replaces it. |
| `bin/game-mode-guard` | POSIX sh | persistent daemon loop | `sh`, `date`, `pgrep`, `kill`, `sleep`, `systemctl`, `xdotool`, `xprop`, `xfconf-query`, `pkill` | Hardcoded config path, renderer path, Picom path, restore source-tree path; broad regex process matching including `.exe`; `eval` on `xdotool --shell`; `/tmp` logs; kills Picom by broad pattern; does not record exactly what it stopped; idle repair restarts wallpaper only. | C guard or safer shell/C hybrid with parsed key=value config, include/exclude patterns, tracked service state/PIDs, non-aggressive polling, project-owned Picom only, restore installed helper. |
| `bin/raise-floating-whisker` | POSIX sh | persistent loop | `sh`, `flock`, `wmctrl`, `awk`, `xprop`, `grep`, `xdotool`, `sleep` | `/tmp` lock; 0.25s polling; panel dimensions hardcoded around 68px; not core wallpaper engine; can persist indefinitely. | Keep as optional shell helper or move out of core; use XDG runtime lock and slower/event-driven behavior if retained. |
| `bin/restore-packaged-xfdesktop` | Bash | one-shot recovery | `bash`, `pgrep`, `nohup`, `/usr/bin/xfdesktop` | Hardcoded HOME/user/UID/session paths; calls installed `stop-custom-xfdesktop`; writes `/tmp/xfdesktop-packaged.pid`; starts non-project packaged desktop. | Rewrite as portable recovery helper using common paths and XDG state; clearly separate from normal engine restore. |
| `bin/run-custom-xfdesktop` | Bash | one-shot starter | `bash`, `mkdir`, `pgrep`, `kill`, `sleep`, `nohup`, process substitution | Hardcoded patched xfdesktop path, HOME/user/UID/session paths, cache log dir, `/tmp` pid; kills any matching `xfdesktop`. | Replace with systemd-managed transparent `xfdesktop` service plus portable helper. |
| `bin/start-animated-wallpaper-with-xfdesktop-icons` | Bash | one-shot restore/bootstrap | `bash`, `sleep`, `systemctl` | Assumes `/run/user/1000` fallback; writes `/tmp/tie-dye-wallpaper-stack.log`; restarts both renderer and icon services; duplicates service orchestration. | Convert to portable bootstrap using common library, XDG runtime lock, journald/systemd services, no `/tmp`. |
| `bin/start-picom-effects` | POSIX sh | persistent while Picom runs | `sh`, `xfconf-query`, `sleep`, `setsid`, `picom`, `raise-floating-whisker` | Hardcoded HOME/user/UID/session paths; starts helper with `/tmp` log; uses bundled Picom path; trap always re-enables XFWM compositor on exit; no distinction from unrelated Picom. | Systemd user service for project Picom with portable paths and tracked state; no broad process matching. |
| `bin/start-transparent-xfdesktop-session` | Bash | one-shot orchestration | `bash`, `xfconf-query`, `pgrep`, `systemctl`, `systemd-run`, `sleep` | Hardcoded HOME/user/UID/session paths; starts Picom with `systemd-run`; restarts wallpaper; starts custom `xfdesktop` with hardcoded env; not same service path as current units. | Replace with portable restore helper that delegates to project services and uses imported session environment. |
| `bin/stop-animated-wallpaper` | POSIX sh | one-shot stop | `sh`, `systemctl`, `pkill`, `notify-send` | Stops legacy/non-project units; broad `pkill` including old Python desktop fallback; leaves icon layer behavior unclear. | Keep as shell recovery command but restrict to project-owned units/processes and XDG state. |
| `bin/stop-custom-xfdesktop` | Bash | one-shot stop | `bash`, `pgrep`, `kill`, process substitution | Hardcoded patched binary path; process-string matching. | Replace with `systemctl --user stop xfdesktop-transparent.service` and portable fallback. |
| `bin/tie-dye-wallpaper` | Bash | one-shot launcher that execs xwinwrap | `bash`, `sleep`, `pkill`, `cd`, `env`, `nice`, `ionice`, `xwinwrap` | Uses current `$HOME` path but kills all `xwinwrap`; overlaps with systemd unit; fixed 8s sleep. | Remove or convert to compatibility wrapper around renderer service. |
| `systemd/user/game-mode-guard.service` | systemd unit | persistent service | user systemd, `game-mode-guard` | `ExecStart=/home/freezer/.local/bin/game-mode-guard`; no environment import; no hardening or config path. | Portable generated/template unit using `%h` or installed path and config/env file only where needed. |
| `systemd/user/tie-dye-wallpaper-mvp.service` | systemd unit | persistent service | user systemd, `nice`, `ionice`, `/usr/local/bin/xwinwrap`, bundled renderer | Hardcoded working directory, HOME/user/UID/session env, XAUTHORITY, DBus; kills `xfdesktop`; fixed `DISPLAY=:0.0`; starts renderer by relative binary; relies on external `/usr/local/bin/xwinwrap`. | Portable renderer service with `%h`, environment import/bootstrap, generated prefix, no fixed display/UID, no direct `xfdesktop` kill except controlled restore operation. |
| `systemd/user/xfdesktop-transparent.service` | systemd unit | persistent service | user systemd, `pkill`, `xfconf-query`, patched `xfdesktop` | Hardcoded HOME/user/UID/session env, binary path; kills all `xfdesktop`; sets global XFCE desktop properties. | Portable icon-layer service with `%h`/prefix, explicit environment import, controlled ownership, no unrelated config overwrite. |
| `autostart/dual-monitor-wallpaper-sync.desktop` | desktop entry | starts persistent watcher | XFCE autostart, installed script | Hardcoded `/home/freezer`; duplicates future systemd choices. | Decide single startup authority; if retained, use bootstrap wrapper path from install templates. |
| `autostart/picom-v13.desktop` | desktop entry | starts persistent Picom via systemd-run | XFCE autostart, `systemd-run`, installed script | Hardcoded `/home/freezer`; ad hoc transient unit; no dependency checks. | Replace with one environment-import/bootstrap autostart and persistent user unit. |
| `autostart/tie-dye-wallpaper.desktop` | desktop entry | starts launcher | XFCE autostart | Hardcoded `/home/freezer`; `X-GNOME-Autostart-enabled=false`; conflicts with systemd renderer service. | Remove or convert to disabled compatibility template; prefer systemd. |
| `runtime/tie-dye-wallpaper/tie-dye-wallpaper` | ELF C binary, source absent | persistent renderer child of xwinwrap | `libraylib.so.600`, `libX11.so.6`, `libc.so.6`, `libm.so.6`, `libxcb.so.1`; runtime `shader.fs`; speed file | Source absent; hardcoded speed path `/home/freezer/.local/state/tie-dye-wallpaper/speed`; loads `shader.fs`; exposes uniforms `resolution`, `time`, `fade`, `fadeTarget`; strings show `request_fade_out` and `fade_out_requested`; no documented shader API; no live shader reload evident from repo. | Add source renderer in C with Makefile, documented shader API, portable speed path, signal/inotify reload, fallback shader, fade behavior, strict warnings. Retain binary until replacement works. |
| `runtime/picom-v13` | ELF C binary, source absent | persistent compositor | Many X11/XCB/GLX libs, `libev`, `libepoxy`, `libdbus-1`, `libpcre2-8`, etc. | Bundled binary provenance only discoverable from strings: `picom v13`, yshui revision `d87a5ba`; no source/build instructions or license file in repo. | Document provenance/licensing and either add rebuild instructions or mark non-reproducible compatibility artifact. |
| `runtime/xfdesktop-transparent/bin/xfdesktop` | ELF C binary, source absent | persistent desktop icon layer | XFCE/GTK/Thunar/Garcon/X11 libraries; debug info present | Patched behavior not documented; no patch source in repo; hardcoded resources likely via install sed/runtime strings; GPL/source obligations unresolved. | Add `patches/xfdesktop-transparent.patch` if recoverable; otherwise document non-reproducible binary-only compatibility artifact and licensing obligations. |
| `runtime/xfdesktop-transparent/bin/xfdesktop-settings` | ELF C binary, source absent | one-shot GUI settings app | XFCE/GTK/X11 libraries | Contains strings for `/home/freezer/.local/opt/xfdesktop-transparent/share/...`; no patch/source provenance. | Same as patched `xfdesktop`; document or replace/rebuild. |
| `runtime/tie-dye-wallpaper/shaders/*.fs` | GLSL | loaded by renderer | OpenGL/GLSL 330 through renderer | Private artwork is committed as editable source; uses `#version 330`, `resolution`, `time`, `fade`, `fadeTarget`; no license/metadata separation. | Move to ignored private artwork staging and provide one public example shader plus optional art-pack mechanism. |
| `config/xfce4/.../xfce4-keyboard-shortcuts.xml` | XFCE XML | installed config data | XFCE xfconf | Contains unrelated personal shortcuts (`spotlight`, `read-screen-text`, `recoll`, `/snap/bin/emote`) and hardcoded `/home/freezer`; installer would copy/transform whole personal config. | Replace with optional helper that adds only project keybindings after backup. |
| `config/game-mode-guard/patterns` | text regex list | config data | `pgrep -af` extended/basic regex behavior | Broad `.exe`, Wine/Proton, launcher patterns can match installers/config tools; no excludes. | New safe `game-mode.conf` with include/exclude regexes and behavior keys parsed without shell execution. |
| `config/picom/picom.conf` | Picom config | config data | Picom v13 | Reasonable but tied to bundled Picom; no dependency/provenance docs. | Retain with docs; install under project config path. |
| `README.md` | Markdown | documentation | none | Documents `/home/freezer` as project source; install instructions still mention `start-transparent-xfdesktop-session`; does not distinguish open source/art/binary-only state. | Rewrite around portable architecture and binary/artwork status. |
| `docs/operations.md` | Markdown | documentation | none | Uses `/tmp` logs and old restore command; rollback includes raw `pkill`. | Rewrite with portable service-based recovery commands. |

## Shell Dialects

| file | shebang | dialect used |
|---|---|---|
| `install.sh` | `#!/usr/bin/env bash` | Bash (`BASH_SOURCE`, arrays not used, strict mode). |
| `bin/animated-wallpaper-picker` | `#!/usr/bin/env bash` | Bash/POSIX mix; uses Bash shebang, no strict pipefail, uses command substitution and `eval`. |
| `bin/animated-wallpaper-speed` | `#!/usr/bin/env bash` | Bash/POSIX mix; no Bash-only syntax obvious. |
| `bin/dual-monitor-wallpaper-sync` | `#!/bin/sh` | POSIX shell. |
| `bin/game-mode-guard` | `#!/bin/sh` | POSIX shell except risky `eval` of `xdotool --shell` output. |
| `bin/raise-floating-whisker` | `#!/bin/sh` | POSIX shell with external `flock`, `awk`, `wmctrl`, `xdotool`. |
| `bin/restore-packaged-xfdesktop` | `#!/usr/bin/env bash` | Bash strict mode. |
| `bin/run-custom-xfdesktop` | `#!/usr/bin/env bash` | Bash strict mode; process substitution. |
| `bin/start-animated-wallpaper-with-xfdesktop-icons` | `#!/usr/bin/env bash` | Bash/POSIX mix; no pipefail. |
| `bin/start-picom-effects` | `#!/bin/sh` | POSIX shell. |
| `bin/start-transparent-xfdesktop-session` | `#!/usr/bin/env bash` | Bash strict mode. |
| `bin/stop-animated-wallpaper` | `#!/bin/sh` | POSIX shell. |
| `bin/stop-custom-xfdesktop` | `#!/usr/bin/env bash` | Bash strict mode; process substitution. |
| `bin/tie-dye-wallpaper` | `#!/usr/bin/env bash` | Bash/POSIX mix. |
| `bin/game-mode-fade` | `#!/usr/bin/env python3` | Python 3 with PyGObject. |

## Hardcoded Runtime Assumptions Found

### User, home, UID, display, session

- `/home/freezer` appears in installer replacement logic, systemd units, scripts, autostarts, docs, keyboard shortcut XML, and binary strings.
- `USER=freezer` and `LOGNAME=freezer` appear in systemd units and shell scripts.
- `/run/user/1000` appears in systemd units and shell scripts.
- `DISPLAY=:0.0` appears in systemd units and Python/shell fallback exports.
- `XAUTHORITY=/home/freezer/.Xauthority` appears in systemd units and scripts.
- `DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus` appears in systemd units and scripts.

### Monitor names

- `bin/dual-monitor-wallpaper-sync` hardcodes `monitorDP-0` and `monitorHDMI-0` under `/backdrop/screen0/.../workspace0`.

### Source tree and broken restore path

- `bin/game-mode-guard` calls `/home/freezer/src/xfdesktop-transparent/start-transparent-xfdesktop-session.sh`, which is not a repository-installed path and is explicitly broken for portable install.

### Temporary files and logs

- `/tmp/game-mode-guard.log`
- `/tmp/game-mode-desktop-restore.log`
- `/tmp/animated-wallpaper-picker.log`
- `/tmp/tie-dye-wallpaper-stack.log`
- `/tmp/raise-floating-whisker.lock`
- `/tmp/raise-floating-whisker.log`
- `/tmp/xfdesktop-packaged.pid`
- `/tmp/xfdesktop-custom.pid`

## External Commands Required by Repository Scripts

Observed external command usage includes:

- Core shell/control: `bash`, `sh`, `id`, `mkdir`, `sed`, `chmod`, `cp`, `rsync`, `find`, `sort`, `cmp`, `sha256sum`, `awk`, `cat`, `printf`, `date`, `sleep`, `nohup`, `setsid`, `env`, `nice`, `ionice`, `flock`.
- systemd/session: `systemctl --user`, `systemd-run --user`.
- XFCE/X11: `xfconf-query`, `xfdesktop`, `xwinwrap`, `xdotool`, `xprop`, `wmctrl`, `picom`, `notify-send`.
- Optional picker UI: `zenity` or `rofi`.
- Python fade utility: `python3`, PyGObject `gi`, GTK 3, GDK, GLib.

## Bundled Binary Dependencies

### `runtime/tie-dye-wallpaper/tie-dye-wallpaper`

- Type: ELF 64-bit PIE executable, not stripped.
- SHA256: `c5431df267955740f781f09f30df435c1e7d82dafa4e0113929cc3e2889a350a`
- BuildID: `8a8aadf755feadd03b942c28f03a5a409720be32`
- Dynamic dependencies from `ldd`/`readelf`: `libraylib.so.600`, `libX11.so.6`, `libc.so.6`, plus transitive `libm.so.6`, `libxcb.so.1`, `libXau.so.6`, `libXdmcp.so.6`, `libbsd.so.0`, `libmd.so.0`.
- Important string evidence: `shader.fs`, uniforms `resolution`, `time`, `fade`, `fadeTarget`, hardcoded speed path `/home/freezer/.local/state/tie-dye-wallpaper/speed`, `request_fade_out`, `fade_out_requested`.

### `runtime/picom-v13`

- Type: ELF 64-bit PIE executable, not stripped.
- SHA256: `d11d0ee4900f09b1308baca6b06c24998b225377688af13085effd998260fce7`
- BuildID: `bf9afadff1d0fbe68e97c97a7c3a113c06d29254`
- String provenance: `picom v13 (https://github.com/yshui/picom.git revision d87a5ba)`.
- Direct dynamic dependencies include `libm.so.6`, `libev.so.4`, `libpixman-1.so.0`, `libX11.so.6`, `libX11-xcb.so.1`, `libxcb.so.1`, `libxcb-shm.so.0`, `libxcb-render-util.so.0`, `libxcb-render.so.0`, `libxcb-util.so.1`, `libxcb-composite.so.0`, `libxcb-damage.so.0`, `libxcb-glx.so.0`, `libxcb-present.so.0`, `libxcb-randr.so.0`, `libxcb-shape.so.0`, `libxcb-sync.so.1`, `libxcb-xfixes.so.0`, `libpcre2-8.so.0`, `libepoxy.so.0`, `libdbus-1.so.3`, `libc.so.6`.

### `runtime/xfdesktop-transparent/bin/xfdesktop`

- Type: ELF 64-bit PIE executable, with debug info, not stripped.
- SHA256: `0013e9a5530a4dac5e31dbc3fb327eafbe8bcbd82ba421f92dee5b99ca4407e0`
- BuildID: `ec2ddd92d068f65bc85bfdf4ca3acba880a492d8`
- Direct dynamic dependencies include `libnotify.so.4`, `libX11.so.6`, `libwnck-3.so.0`, `libxfconf-0.so.3`, `libexo-2.so.0`, `libgarcon-gtk3-1.so.0`, `libgarcon-1.so.0`, `libxfce4ui-2.so.0`, `libxfce4util.so.7`, `libthunarx-3.so.0`, `libgtk-3.so.0`, `libgdk-3.so.0`, `libpango-1.0.so.0`, `libcairo.so.2`, `libgdk_pixbuf-2.0.so.0`, `libgio-2.0.so.0`, `libgobject-2.0.so.0`, `libglib-2.0.so.0`, `libc.so.6`.
- Source/patch is absent from this repository.

### `runtime/xfdesktop-transparent/bin/xfdesktop-settings`

- Type: ELF 64-bit PIE executable, with debug info, not stripped.
- SHA256: `c93081dcbbc33e6e65e00be5e3dbca5e04b35331d98ba3c757861729369e9baf`
- BuildID: `02eb9179ef3812be0dd1a3c13cee7c1662d5408d`
- Direct dynamic dependencies include `libxfconf-0.so.3`, `libxfce4ui-2.so.0`, `libxfce4util.so.7`, `libwnck-3.so.0`, `libX11.so.6`, `libgtk-3.so.0`, `libgdk-3.so.0`, `libcairo-gobject.so.2`, `libcairo.so.2`, `libgdk_pixbuf-2.0.so.0`, `libgio-2.0.so.0`, `libgobject-2.0.so.0`, `libglib-2.0.so.0`, `libc.so.6`.
- String evidence includes `/home/freezer/.local/opt/xfdesktop-transparent/share/backgrounds/xfce/xfce-shapes.svg` and `/home/freezer/.local/opt/xfdesktop-transparent/share/locale`.

## Renderer Behavior From Repository Evidence

- `systemd/user/tie-dye-wallpaper-mvp.service` starts `xwinwrap` with `-- ./tie-dye-wallpaper --wid WID` from `WorkingDirectory=/home/freezer/.local/lib/tie-dye-wallpaper`.
- `bin/tie-dye-wallpaper` also starts `xwinwrap` from `$HOME/.local/lib/tie-dye-wallpaper` after killing existing `xwinwrap`.
- Renderer binary strings show it loads `shader.fs` and has uniforms `resolution`, `time`, `fade`, and `fadeTarget`.
- Renderer binary strings show it reads speed from `/home/freezer/.local/state/tie-dye-wallpaper/speed` unless source not present says otherwise. The repo contains no renderer source to verify alternatives.
- Renderer binary strings show `signal`, `request_fade_out`, and `fade_out_requested`, supporting SIGUSR1 fade-out behavior used by `game-mode-guard` (`kill -USR1`).
- No repository source indicates live shader reload. The current picker replaces `shader.fs`, then restarts `tie-dye-wallpaper-mvp.service`, sleeps, and restarts `xfdesktop-transparent.service`.

## Shader Switching

`bin/animated-wallpaper-picker`:

1. Resolves runtime to `$HOME/.local/lib/tie-dye-wallpaper`.
2. Lists hardcoded ordered shader filenames and then any other `*.fs` in the shader directory.
3. Determines current shader by state file or by comparing `shader.fs` hash to known shader files.
4. Copies the selected shader to `shader.fs`.
5. Writes current shader filename to `$XDG_STATE_HOME/tie-dye-wallpaper/current-shader`.
6. Restarts `tie-dye-wallpaper-mvp.service`.
7. Sleeps one second and restarts `xfdesktop-transparent.service`.
8. Sends a desktop notification if `notify-send` exists.

Current problems: copying instead of atomic selected-state update, no precompile validation before replacing active shader, no live reload, unsafe `eval`, names with spaces unsafe, `/tmp` logs.

## Speed Control

`bin/animated-wallpaper-speed`:

- Stores numeric speed in `$XDG_STATE_HOME/tie-dye-wallpaper/speed` or `$HOME/.local/state/tie-dye-wallpaper/speed`.
- Stores label in adjacent `speed-label`.
- Presets: `frozen=0.0`, `slow=0.35`, `medium=1.0`, `motion-sickness=2.85`.
- Supports `up`, `down`, preset names, `current`, `value`, `list`.
- The renderer binary contains the hardcoded speed file path `/home/freezer/.local/state/tie-dye-wallpaper/speed`; this matches the author's default but is not portable.

## SIGUSR1 Fade Behavior

`bin/game-mode-guard` gathers renderer PIDs with:

```sh
pgrep -f '^/home/freezer/.local/lib/tie-dye-wallpaper/tie-dye-wallpaper --wid'
```

If found, it sends `kill -USR1` to request native wallpaper fade out. Renderer strings include `request_fade_out` and `fade_out_requested`. If wallpaper does not exit within three seconds, the guard stops the `tie-dye-wallpaper-mvp.service`.

`bin/game-mode-fade` separately implements a GTK fullscreen fade overlay for `in`, `out`, and `pulse` modes, but the current guard path appears to rely on native renderer fade for wallpaper fade-out and fade-in.

## Game Mode Shutdown And Restoration

`bin/game-mode-guard` runs an infinite loop with a default one-second sleep.

Detection:

- Reads regex lines from `/home/freezer/.config/game-mode-guard/patterns`.
- Uses `pgrep -af` on each pattern.
- Also checks visible fullscreen windows using `xdotool search --onlyvisible --name '.*'`, `xprop _NET_WM_STATE`, `xprop WM_CLASS`, and geometry from `xdotool getwindowgeometry --shell`.
- Excludes some XFCE/panel/window classes.

Enter:

1. Optionally waits `LAUNCH_GRACE_SECONDS` unless fullscreen window detected.
2. Calls `fade_stop_wallpaper` (`SIGUSR1`, then systemd stop fallback).
3. Kills Picom by `pkill -f '/home/freezer/.local/bin/picom.*picom\.conf'`.
4. Disables XFWM compositing via `xfconf-query -c xfwm4 -p /general/use_compositing -s false`.

Restore:

1. Waits `EXIT_GRACE_SECONDS`.
2. Calls broken source-tree path `/home/freezer/src/xfdesktop-transparent/start-transparent-xfdesktop-session.sh`.
3. Calls `ensure_wallpaper`, which restarts `tie-dye-wallpaper-mvp.service` and polls with `wallpaper_running`.

Current problems: broad game patterns, broad Picom kill, no include/exclude config, no exact state tracking, broken restore path, hardcoded runtime paths.

## Transparent Xfdesktop Startup

There are three competing mechanisms:

- `systemd/user/xfdesktop-transparent.service` starts `/home/freezer/.local/opt/xfdesktop-transparent/bin/xfdesktop --disable-wm-check` after setting icon style and transparent backdrop.
- `bin/start-transparent-xfdesktop-session` starts a transient `custom-xfdesktop` unit with hardcoded environment and same patched binary.
- `bin/run-custom-xfdesktop` starts the patched binary directly with `nohup`.

The current service kills all `xfdesktop` before starting, then sets:

- `/desktop-icons/style = 2`
- `/backdrop/transparent-background = true`

## Picom Startup

- `autostart/picom-v13.desktop` runs `systemd-run --user --unit=picom-effects --collect /home/freezer/.local/bin/start-picom-effects`.
- `bin/start-picom-effects` disables XFWM compositing, starts `raise-floating-whisker`, then runs `/home/freezer/.local/bin/picom --config /home/freezer/.config/picom/picom.conf` in foreground.
- On exit/trap it re-enables XFWM compositing.
- There is no persistent checked-in `picom-effects.service`; Picom is started as a transient user unit.

## Monitor Sync

`bin/dual-monitor-wallpaper-sync` is a persistent POSIX shell watcher. It assumes exactly two XFCE monitor property bases:

- `/backdrop/screen0/monitorDP-0/workspace0`
- `/backdrop/screen0/monitorHDMI-0/workspace0`

It reads `last-image`, sets both `image-style` properties to `6`, and mirrors `last-image` from one monitor to the other whenever `xfconf-query -m` emits matching property paths. It does not call `xrandr`; it does not discover current monitors.

## Installation Behavior

`install.sh`:

- Requires Bash.
- Computes repo root from `BASH_SOURCE[0]`.
- Installs scripts to `$HOME/.local/bin`.
- Installs renderer to `$HOME/.local/lib/tie-dye-wallpaper`.
- Installs patched desktop runtime to `$HOME/.local/opt/xfdesktop-transparent`.
- Installs Picom as `$HOME/.local/bin/picom`.
- Installs Picom/game-mode config under `$HOME/.config`.
- Installs all autostart desktop files.
- Installs all systemd user service files.
- Runs `systemctl --user daemon-reload || true`.

It does not currently install the checked-in XFCE keyboard shortcut XML, despite it being included in the repo. It does not install an uninstall manifest or dependency checker.

## Private Artwork Exposure

The repo currently commits editable GLSL shader artwork:

- `aurora-ribbons.fs`
- `deep-ocean.fs`
- `kaleidoscope-tunnel.fs`
- `motion-halftone.fs`
- `plasma-lava.fs`
- `qr-cube-maze.fs`
- `sky-water-wave.fs`
- `tie-dye.fs`

These are private/artistic compositions under `runtime/tie-dye-wallpaper/shaders/` and should not be the final public example layout. Public operation should later use a minimal example shader only, with private art packaged separately.

## Immediate Refactor Risks

- The current working behavior depends on delicate X11 stacking order between `xwinwrap` and patched `xfdesktop`.
- The renderer source is absent, so replacing it must be done behind tests and kept alongside the current binary until parity is proven.
- The patched `xfdesktop` source/patch is absent. Because XFCE components are likely GPL-family software, source-distribution obligations need a dedicated licensing/provenance pass before claiming the project is fully open source.
- The committed keyboard shortcut XML includes unrelated personal shortcuts and should not be installed as project configuration.
- The installer rewrites hardcoded paths but does not make runtime logic truly portable.

## Proposed Phase 2 Starting Point

1. Add `lib/xfce-plasma-common.sh` with XDG/session/path resolution and small key=value config parser.
2. Add tests around path resolution and hardcoded-user detection before modifying scripts.
3. Convert short-lived shell scripts to source the common library.
4. Generate or install portable systemd units using `%h` and imported graphical session environment instead of fixed `/home/freezer` and `/run/user/1000`.
5. Fix `bin/game-mode-guard` restore path to call the installed helper path, then later replace the entire guard behavior under the game-mode phase.
