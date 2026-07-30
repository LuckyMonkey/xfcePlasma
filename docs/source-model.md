# Background source model

xfcePlasma keeps one background session beneath transparent xfdesktop. The
legacy `tie-dye-wallpaper-mvp.service` unit name is retained for compatible
upgrades, but it now launches the source-neutral `xfce-plasma-background`
controller.

The lifecycle is:

```text
xfce-plasma-background start|stop|restart|pause|resume|status|reload
xfce-plasma-background shader SOURCE
xfce-plasma-background fallback
```

Persistent selection is stored in
`${XDG_STATE_HOME:-~/.local/state}/xfce-plasma/active-source` as validated
`key=value` data. The controller recognizes only documented keys and never
sources the file as shell code. Transient backend PID, state, and X11 window
information lives below `$XDG_RUNTIME_DIR/xfce-plasma`.

Current shader selections migrate automatically. `tie-dye`, `tie-dye.fs`, and
`Tie Dye` resolve to `plasma`; the legacy shader state and shader source remain
untouched. Repeating migration is harmless.

The controller recognizes source types `shader`, `video`, `stream`, and
`fallback`. Raylib remains the shader backend. Local video uses mpv embedded in
the same xwinwrap X11 window with looping, muted audio, cover/contain/stretch
fit, safe hardware-decoding selection, and unit-scoped pause/resume. Video
source files remain in their original location; only a small reference file is
stored under `$XDG_CONFIG_HOME/xfce-plasma/sources`.

VLC detection and preference validation are present, but actual VLC embedding
remains experimental until its adapter passes live X11 tests. Missing media
backends disable media sources without affecting shaders.

## Performance profile

`performance_mode` in `$XDG_CONFIG_HOME/xfce-plasma/settings.conf` accepts
`automatic`, `low`, `balanced`, or `high`. Automatic is the default. Detection
uses actual OpenGL renderer/version information and total desktop geometry,
not a GPU-brand allowlist. The cached profile lives at
`$XDG_CACHE_HOME/xfce-plasma/performance-profile` and records the selected FPS,
shader render scale, reason, and hardware fingerprint. Run
`xfce-plasma-background performance redetect` after a driver or display change.
