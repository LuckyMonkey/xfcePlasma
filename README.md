# xfcePlasma

xfcePlasma is a shader-driven animated background system for XFCE on X11.

It combines a native raylib renderer, a GTK 3 settings application, Bash
controllers, systemd user services, xwinwrap, Picom, and a patched transparent
xfdesktop. XFWM remains the window manager and XFCE desktop icons remain
interactive above the animation.

This is not KDE Plasma, does not require KDE, and does not claim Wayland
support. It has no Python, Electron, web server, or root-install requirement.

## Supported environment

The current reference platform is Ubuntu 24.04.4 LTS with Xfce 4.18.3, an X11
session, GTK 3.24, raylib 6.0, and Picom v13. The build and non-graphical test
suite also run without changing the active desktop.

Other XFCE/X11 distributions may work when they provide compatible GTK 3,
raylib, X11, xfconf, systemd-user, and xwinwrap components. The patched
xfdesktop artifact is based on Ubuntu `xfdesktop4` `4.18.1-1build3`; rebuild it
for a different target and user prefix.

## Architecture

```text
GTK settings UI
        |
        v
Bash background/source controller
        |
        v
validated XDG source state, shader, and metadata files
        |
        v
systemd user services
        |
        v
xwinwrap + selected backend (Raylib shaders; media adapters in progress)
        |
        v
Picom + transparent xfdesktop
```

Picom supplies X11 compositing and window effects while XFWM remains the window
manager. xwinwrap owns the desktop-sized renderer window. The patched
xfdesktop supplies a transparent, interactive desktop icon layer. Game mode
hands off to a dark, desaturated static XFCE wallpaper before stopping the
animated components, then fades the raster to black as animation returns.

## Repository layout

```text
src/renderer/                 raylib/X11 renderer source
src/settings/                 GTK 3 settings source
bin/                          Bash controllers and focused helpers
lib/                          shared Bash path/state functions
runtime/tie-dye-wallpaper/    release fallback, active seed, bundled shaders
runtime/xfdesktop-transparent/ reference patched xfdesktop runtime
runtime/picom-v13             pinned compositor compatibility artifact
assets/thumbnails/            static shader gallery images
systemd/user/                 user service units
scripts/                      explicit third-party rebuild scripts
patches/                      recovered third-party source patch
tests/                        shell integration and boundary tests
docs/                         operations, authoring, audit, and provenance
```

The visible source is authoritative for both project-owned native programs:

```text
src/renderer/main.c -> build/xfce-plasma-renderer
src/settings/main.c -> build/xfce-plasma-settings-ui
```

Normal installation uses those fresh `build/` artifacts. The matching native
copies in `runtime/` are an explicit release fallback only.

## Dependencies

Build requirements:

- a C11 compiler and GNU make
- `pkg-config`
- raylib development files
- GTK 3 development files
- X11 development files

Required runtime capabilities:

- Bash
- an XFCE X11 session with `xfconf-query` and `xrandr`
- a systemd user manager
- xwinwrap

Feature-specific tools:

- ImageMagick `import` and `convert` for the game-mode raster handoff
- `xdotool` for fullscreen/game detection
- `wmctrl` for the floating Whisker helper

Optional media tools:

- mpv for local video and RTSP sources
- VLC as an alternate experimental backend
- FFmpeg or ffmpegthumbnailer for explicitly requested thumbnails

Shaders install and run without any media backend. Video files are referenced
in place, loop silently by default, and use mpv's `auto-safe` hardware decoding
without assuming a GPU vendor or CUDA.

Automatic performance mode is the default. It caches a feature-based profile
from the active OpenGL renderer and total desktop geometry, then selects Low
(20 FPS, 0.5 render scale), Balanced (30 FPS, 0.75), or High (60 FPS, 1.0).
Manual overrides are available with `xfce-plasma-background performance MODE`.
Only animated background content is scaled; xfdesktop icons stay native size.

Desktop notifications and a Zenity or rofi shell picker are optional. Run:

```bash
make check-build-deps
make check-runtime-deps
make check-deps
```

Missing dependencies produce concise package/capability messages rather than
compiler or pkg-config output.

## Build and test

```bash
make clean
make
make check
```

Both binaries report the single version from `VERSION`:

```bash
build/xfce-plasma-renderer --version
build/xfce-plasma-settings-ui --version
```

`make check` builds first, then runs the shell tests. It does not install,
restart the desktop, or overwrite live user data.

## Install and upgrade

Preview the exact user-scoped operation:

```bash
./install.sh --check
./install.sh --dry-run
```

Install freshly built project binaries:

```bash
./install.sh
```

No root access is used. Files are installed below the current user's XDG
configuration, data, and state roots plus `~/.local/bin`,
`~/.local/lib`, and `~/.local/opt`.

Repeated installation is a deterministic upgrade. The installer validates the
old manifest, writes individual files atomically, removes obsolete files owned
by the old manifest, and commits the new manifest last. It never places user
configuration, current state, or user-created shaders in the removal set.

Precompiled project binaries are available only as an explicit fallback:

```bash
./install.sh --use-bundled-runtime
```

This option does not solve the reference xfdesktop artifact's compiled-prefix
limitation. Read `docs/binary-provenance.md` before using it on another account.

After installation:

```bash
~/.local/bin/start-animated-wallpaper-with-xfdesktop-icons
```

XFCE autostart is the single session-start owner for the renderer and
transparent desktop-icon layer. It waits for the XRandR monitor layout to
settle, then starts both systemd user services together. Do not separately
enable those two services: doing so starts the renderer before XFCE finishes
monitor setup and creates a second restart during login. The game guard remains
an enabled systemd user service.

## Uninstall and recovery

Preview or perform manifest-bounded uninstall:

```bash
./install.sh --dry-run --uninstall
./install.sh --uninstall
```

Uninstall removes project-owned installed files only. Configuration, state,
user shaders, and anything outside the approved paths survive.

To return immediately to an ordinary XFCE desktop:

```bash
~/.local/bin/restore-packaged-xfdesktop
xfconf-query -c xfwm4 -p /general/use_compositing -s true
```

If the project helper is unavailable:

```bash
systemctl --user disable --now tie-dye-wallpaper-mvp.service xfdesktop-transparent.service
pkill -x xwinwrap
xfdesktop --disable-wm-check
```

## Settings and everyday use

Open the unified settings application:

```bash
~/.local/bin/xfce-plasma-settings
```

The Collection view presents a scrollable thumbnail list with display names,
categories, descriptions, origin badges, and a clear active state. It keeps
selection, previous/next, motion speed, pause/resume, preview, and service
status available without opening an editor.

Create / Advanced contains GLSL editing, create, duplicate, import, replace,
local deletion, editable keybindings, game/desktop controls, and diagnostics.
Bundled shaders can be edited for compatibility but cannot be deleted; duplicate
one before making a user-owned variant.

Command-line equivalents include:

```bash
animated-wallpaper-picker next
animated-wallpaper-picker previous
animated-wallpaper-picker set ricky.fs
animated-wallpaper-speed up
animated-wallpaper-speed down
xfce-plasma-settings shortcuts list
xfce-plasma-background status
xfce-plasma-background shader plasma
xfce-plasma-background video "/path/to/Rain Loop.webm"
```

The common background lifecycle is `start`, `stop`, `restart`, `pause`,
`resume`, `status`, and `reload`. The historical
`tie-dye-wallpaper-mvp.service` filename remains as the single generic
background service for upgrade compatibility; it is no longer tied to one
shader implementation.

The featured classic source is Plasma. Upgrades preserve the
user's current selection rather than silently changing it.

Default shortcuts:

```text
Ctrl+Alt+Shift+Left/Right  previous/next shader
Ctrl+Alt+Shift+Up/Down     slower/faster motion
Ctrl+Alt+Shift+F12         emergency animation stop
```

All shortcut bindings can be changed in the settings application.

## Shader collection and authoring

The bundled gallery is curated into Ambient, Graphic, and Scenic groups. Shader
identity remains in the artwork; the UI does not rewrite shader code to
normalize it.

Fragment shaders use GLSL 3.30. `resolution` and `time` uniforms are required.
`speed`, `fade`, and `fadeTarget` are supported optional uniforms. Shader
filenames must end in `.fs`, use safe filename characters, and cannot begin
with `.` or `-`.

Optional metadata uses a neighboring `.meta` sidecar with simple `key=value`
fields:

```text
id
display_name
category
description
author
thumbnail
sort_order
```

Static repository thumbnails follow
`assets/thumbnails/<shader-id>.png`. Missing metadata or thumbnails receive a
readable filename-derived label and a neutral fallback. No thumbnail daemon is
run and thumbnails are not regenerated at UI startup.

User shaders live under
`${XDG_DATA_HOME:-$HOME/.local/share}/xfce-plasma/user-shaders`. A bad hot
reload leaves the previous GPU program running; a bad initial shader falls back
in memory to a safe built-in gradient.

Old `tie-dye`, `tie-dye.fs`, and `Tie Dye` selections migrate idempotently to
`plasma` while the old files remain installed as compatibility aliases. Plasma
describes the classic procedural graphics effect; it does not refer to KDE
Plasma.

See `docs/shader-api.md` for the complete contract and examples, and
`docs/source-model.md` for source state and lifecycle details.

## Game mode

Game detection patterns are stored in:

```text
~/.config/game-mode-guard/patterns
```

When a match starts, the guard captures the animated desktop, reduces
saturation and brightness, assigns per-monitor static XFCE wallpapers, then
stops animation and project Picom. When the match exits, the raster fades to
black and the previous wallpaper/compositor state and full-color animation
return. Only components active before the handoff are restored.

## Diagnostics

```bash
make doctor
~/.local/bin/xfce-plasma-doctor
~/.local/bin/xfce-plasma-settings version
```

Doctor reports `OK`, `WARNING`, `ERROR`, and `OPTIONAL` states with one
corrective action for each problem. It checks the X11 session, DISPLAY,
binaries and versions, shaders, writable XDG paths, services, process counts,
Picom, transparent xfdesktop, optional game-guard tools, and source/install
artifact mismatches.

## Troubleshooting

### Black wallpaper

Run `xfce-plasma-doctor`, confirm DISPLAY/X11 and both desktop services, then
inspect:

```bash
journalctl --user -u tie-dye-wallpaper-mvp.service --since "10 minutes ago"
```

Use `animated-wallpaper-picker set motion-halftone.fs` to select a known bundled
shader. If the renderer itself fails, restore ordinary XFCE using the recovery
commands above.

### Shader compile failure

The renderer keeps the previous program on a failed reload. Read the renderer
journal for the GLSL compiler message. Confirm `#version 330`, `time`,
`resolution`, and assignment to `finalColor`; then save again.

### Desktop icons but no animation, or animation but no icons

Restart the coordinated stack:

```bash
~/.local/bin/start-animated-wallpaper-with-xfdesktop-icons
```

Confirm `/backdrop/transparent-background` is enabled in xfconf and that only
one xfdesktop process is running. Do not replace the live patched xfdesktop
blindly when doctor reports a repository/live checksum difference.

### Missing transparency

Confirm Picom is running and the patched xfdesktop service, not the packaged
xfdesktop, owns the icon layer. Check:

```bash
systemctl --user status xfdesktop-transparent.service --no-pager
pgrep -af xfdesktop
```

### Picom conflict

Only one compositor should be active. Stop another Picom instance and disable
XFWM compositing while project Picom runs. To abandon project Picom, stop it and
set `/general/use_compositing` back to `true` in the `xfwm4` channel.

### Wrong session type

xfcePlasma supports XFCE on X11 only. Log out and choose an Xorg/X11 session if
`echo "$XDG_SESSION_TYPE"` does not print `x11`.

### Service does not start

Use doctor, then:

```bash
systemctl --user daemon-reload
systemctl --user status SERVICE.service --no-pager
journalctl --user -u SERVICE.service --since "10 minutes ago"
```

Verify that the user systemd manager has DISPLAY and XAUTHORITY from the current
session.

## Provenance and release status

`docs/binary-provenance.md` records upstream projects, versions/commits,
licenses, patches, build paths, limitations, and checksums for all opaque
components. Build scripts download source only when explicitly invoked; normal
startup and installation never download or replace system software.

The repository does not yet include a maintainer-selected project-wide license,
and the exact source/license of the external reference xwinwrap remains
unresolved. Those are public-release blockers, not hidden assumptions.
