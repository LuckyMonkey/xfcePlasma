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

The controller already reserves source types `shader`, `video`, `stream`, and
`fallback`. This phase routes shaders and the ordinary static fallback through
the common lifecycle. Media adapters are enabled only as their backend and
tests land; their absence does not affect shaders.
