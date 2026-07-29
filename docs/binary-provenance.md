# Binary provenance

This record covers every ELF artifact shipped by xfcePlasma and the external
`xwinwrap` executable used on the reference desktop. Verify shipped files with:

```bash
sha256sum --check runtime/SHA256SUMS
```

Checksums identify the artifacts in this repository. They are not a promise
that a rebuild will be bit-for-bit identical across compiler, linker, and
dependency versions.

## Native xfcePlasma programs

| Artifact | Source | Version | Origin |
|---|---|---|---|
| `runtime/tie-dye-wallpaper/tie-dye-wallpaper` | `src/renderer/main.c` | `0.1.0-alpha.1` | Release fallback built by this repository's Makefile |
| `runtime/xfce-plasma-settings-ui` | `src/settings/main.c` | `0.1.0-alpha.1` | Release fallback built by this repository's Makefile |

Normal installation does not use these copies. It builds
`build/xfce-plasma-renderer` and `build/xfce-plasma-settings-ui` from visible
source. The runtime copies are selected only by
`./install.sh --use-bundled-runtime`.

The renderer links to raylib 6, X11, libc, and libm on the reference build.
The settings application links to GTK 3 and its normal GLib/X11 stack. Neither
program is patched from a third-party binary.

## Picom

- Upstream: <https://github.com/yshui/picom>
- Version: v13
- Commit: `d87a5ba3af7a9ee3c4e040ee29b2dea7e9e46317`
- Upstream license expression: `MPL-2.0 AND MIT`
- Repository artifact: `runtime/picom-v13`
- SHA-256: `d11d0ee4900f09b1308baca6b06c24998b225377688af13085effd998260fce7`
- Reference compiler: GCC 13.3.0 on Ubuntu 24.04
- Project patch: none detected

Picom is bundled so the tested v13 compositor behavior does not depend on the
distribution Picom version. `scripts/build-picom.sh` checks out the full pinned
commit and builds it with Meson. It downloads only when explicitly given
`--download`; `--source-dir` performs an offline build from an existing clone.
The original build directory and full Meson log were not retained, so the
checked-in checksum cannot yet be claimed as bit-reproducible.

## Transparent xfdesktop

- Upstream: <https://gitlab.xfce.org/xfce/xfdesktop>
- Distribution source: Ubuntu `xfdesktop4` `4.18.1-1build3`
- Upstream/distribution license: `GPL-2+`
- Patch: `patches/xfdesktop-transparent.patch`
- Repository binaries:
  - `runtime/xfdesktop-transparent/bin/xfdesktop`
  - `runtime/xfdesktop-transparent/bin/xfdesktop-settings`
- SHA-256:
  - `xfdesktop`: `0013e9a5530a4dac5e31dbc3fb327eafbe8bcbd82ba421f92dee5b99ca4407e0`
  - `xfdesktop-settings`: `c93081dcbbc33e6e65e00be5e3dbca5e04b35331d98ba3c757861729369e9baf`
- Reference compiler: GCC 13.3.0 on Ubuntu 24.04

The recovered patch adds the opt-in xfconf property
`/backdrop/transparent-background`, selects an RGBA visual, clears the opaque
window region, and preserves icon drawing over the transparent surface. It is
the aggregate of local commits `843514c`, `80b2c20`, `09551ee`, and `efb1573`
on top of an imported Ubuntu source baseline.

Pinned Ubuntu source inputs:

| File | SHA-256 |
|---|---|
| `xfdesktop4_4.18.1.orig.tar.bz2` | `ef9268190c25877e22a9ff5aa31cc8ede120239cb0dfca080c174e7eed4ff756` |
| `xfdesktop4_4.18.1-1build3.debian.tar.xz` | `508cfa9473e66fed45873f4391d45a4e8f0d9f6105e15e8fc47990b76cfc4ca7` |

`scripts/build-xfdesktop.sh` applies the published patch, runs the upstream
test suite, and stages the result. It downloads the Ubuntu source package only
when explicitly given `--download`. An offline unpacked source tree can be
passed with `--source-dir`.

The binary embeds its configured resource prefix. The repository artifact was
built for `/home/freezer/.local/opt/xfdesktop-transparent` and is therefore a
reference-platform compatibility artifact, not a portable release binary.
Public packages must rebuild it for the target user's prefix or replace the
compile-time resource lookup before claiming portable installation.

The currently installed desktop binary on the development workstation has
SHA-256 `c6430bd189e1adbd04d934f77a8a5a686320091ecadd279cd200f777d533bf4c`.
It includes an additional uncommitted, user-specific icon-sorting hook that
calls `/home/freezer/.local/bin/sort-desktop-icons`. That delta is deliberately
excluded from the public transparency patch and repository artifact.

## xwinwrap

`xwinwrap` is not stored in this repository; it is a required external runtime
capability. The reference workstation uses `/usr/local/bin/xwinwrap`:

- SHA-256: `815990ddac471b369ea670f4b716eb14f17be8d78f80f50fcfacf7161b85036a`
- Build ID: `2d257968a2b2362ecdf00b5a68b122ece9148284`
- Compiler: GCC 13.3.0 on Ubuntu 24.04
- Recorded build directory: `/tmp/tie-dye-xwinwrap`
- Recorded source file: `xwinwrap.c`

The likely upstream lineage is the archived
<https://github.com/r00tdaemon/xwinwrap> repository, whose last commit is
`ec32e9b72539de7e1553a4f70345166107b431f7`. The exact source revision used for
the local binary was not retained, and that upstream repository does not
declare a license. For those reasons xfcePlasma does not bundle, redistribute,
or claim a reproducible build for xwinwrap. Resolving its source and licensing
is a release blocker for any distribution that intends to ship it.

## Licensing status

The repository does not yet contain a project-wide license covering the
xfcePlasma C, Bash, shader, metadata, thumbnail, and documentation work. A
maintainer must select and add that license before describing the repository
itself as open source. Third-party notices and corresponding license texts must
also accompany any binary release. This document records the current facts; it
does not grant permissions or replace legal review.
