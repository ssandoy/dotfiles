# XKB

Linux keyboard layout for typing Norwegian letters on a US keyboard.

## Mappings

- `Alt+O` -> `ø`
- `Alt+E` -> `æ`
- `Alt+A` -> `å`
- `Alt+Shift+O` -> `Ø`
- `Alt+Shift+E` -> `Æ`
- `Alt+Shift+A` -> `Å`

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
