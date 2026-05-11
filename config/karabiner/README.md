# Karabiner-Elements

macOS mappings for typing Norwegian letters on a US keyboard.

## Mappings

- `Right Option+O` -> `ø`
- `Right Option+E` -> `æ`
- `Right Option+A` -> `å`
- `Right Option+Shift+O` -> `Ø`
- `Right Option+Shift+E` -> `Æ`
- `Right Option+Shift+A` -> `Å`

On a macOS US input source, `Right Option+A/O` already produce `å/ø`.
This Karabiner config maps `Right Option+E` to `æ` so the full mnemonic layer
works without breaking common `Ctrl` and `Cmd` shortcuts.

## Setup

Install Karabiner-Elements, then stow this package:

```sh
cd config
stow karabiner
```

Open Karabiner-Elements once after stowing so macOS can grant the required
input monitoring permissions.
