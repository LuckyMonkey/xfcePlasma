# Shader API

xfcePlasma fragment shaders target desktop OpenGL GLSL 3.30:

```glsl
#version 330
in vec2 fragTexCoord;
uniform float time;
uniform vec2 resolution;
uniform float speed;
uniform float fade;
out vec4 finalColor;
```

`time` is accumulated animation time in seconds after applying the configured
speed. `speed` is the current multiplier, and `resolution` is the render target
size in pixels. `fade` moves from zero to one during startup and live reload,
and back to zero during a requested shutdown. Most shaders should animate from
the already-scaled `time` value and use `speed` only when they need to react to
the selected rate.

`fragTexCoord` ranges from `(0, 0)` to `(1, 1)`. Shaders must assign an RGBA
value to `finalColor`. Keep expensive loops bounded and avoid unnecessary
texture reads: the renderer normally draws the shader at 30 FPS across the
combined X11 desktop.

The default cap is 30 FPS. Set `WALLPAPER_FPS` in the renderer service
environment to an integer from 1 through 240 to override it. A frozen wallpaper
automatically drops to 5 FPS (or the lower configured cap) after fades finish.

## Live reload

`animated-wallpaper-picker set NAME` atomically replaces the active
`shader.fs`. The persistent C renderer watches its runtime directory with
inotify, fades to black, compiles the candidate, and fades back in. A successful
change does not restart xwinwrap or xfdesktop.

If compilation fails or the required `time` and `resolution` uniforms are
missing, the renderer logs the compiler error and keeps the previous GPU
program. Inspect errors with:

```bash
journalctl --user -u tie-dye-wallpaper-mvp.service --since "5 minutes ago"
```

At initial startup, an invalid active shader is replaced in memory by a safe
built-in gradient.

## Installing user shaders

Import a shader without modifying the built-in artwork directory:

```bash
animated-wallpaper-picker user-add "/path/to/My Shader.fs"
animated-wallpaper-picker set "My Shader.fs"
```

The same operations are available in the unified settings panel. CLI source management is also available:

```bash
animated-wallpaper-picker create "My Copy.fs" tie-dye.fs
animated-wallpaper-picker read "My Copy.fs"
animated-wallpaper-picker replace "My Copy.fs" /tmp/edited.fs
animated-wallpaper-picker remove "My Copy.fs"
```

User shaders are stored under
`${XDG_DATA_HOME:-$HOME/.local/share}/xfce-plasma/user-shaders`. Names may
contain spaces. A user shader cannot replace a built-in shader with the same
filename.

See `examples/shaders/basic-gradient.fs` for a minimal implementation.

## Metadata and thumbnails

A shader does not need metadata to work. Bundled and user shaders may add an
optional sidecar next to the GLSL file:

```text
shaders/tie-dye.fs
shaders/tie-dye.meta
```

Sidecars use simple `key=value` lines. Recognized fields are `id`,
`display_name`, `category`, `description`, `author`, `thumbnail`, and
`sort_order`. Unknown fields are ignored. Missing metadata falls back to a
display name derived from the `.fs` filename, the Experimental category, and a
neutral thumbnail.

Repository thumbnails are static PNG files stored at
`assets/thumbnails/<shader-id>.png`. Installed copies live under the project
XDG data directory. The settings UI does not render thumbnails during launch,
and xfcePlasma does not run a thumbnail daemon. Third-party shaders remain
fully selectable when their sidecar or thumbnail is absent.
