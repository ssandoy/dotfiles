# XKB

Linux keyboard layout for typing Norwegian letters on a US keyboard.

## Mappings

- `Right Alt+O` -> `ø`
- `Right Alt+E` -> `æ`
- `Right Alt+A` -> `å`
- `Right Alt+Shift+O` -> `Ø`
- `Right Alt+Shift+E` -> `Æ`
- `Right Alt+Shift+A` -> `Å`

## Setup

Stow this package:

```sh
cd config
stow xkb
```

For X11 sessions, activate the layout with:

```sh
use-us-norwegian-xkb
```

Wayland compositors also use XKB, but activation is compositor-specific. Point
the compositor to the custom `us-norwegian` layout, or set
`XKB_CONFIG_ROOT=$HOME/.config/xkb` before the compositor starts if it does not
search user XKB configs automatically.
