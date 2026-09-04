# Zed Configuration

This package keeps Zed user settings and keybindings in the dotfiles repo.

## Structure

- `.config/zed/settings.json`: uses Zed's VS Code base keymap.
- `.config/zed/keymap.json`: custom bindings translated from `.vscode/keybindings.json`.
- `zed-macos` (separate stow package, macOS only): `.local/bin/zed` wraps `Zed.app`'s bundled CLI. Linux/WSL installs of Zed manage their own `~/.local/bin/zed` symlink via the official installer, so this package must not be stowed there.

## Applying on WSL vs Windows

`stow zed` only applies to the current Unix home directory. When Zed is installed on Windows and this repo is opened from WSL, use the repository bridge instead:

```bash
./link-zed-windows.sh
```

That writes links, or copies as a fallback, into `%APPDATA%\Zed`, which is where Windows Zed reads `settings.json` and `keymap.json`.

## Translation Notes

Zed already supports a VS Code base keymap, so this config only carries over custom overrides with clear Zed actions. Some VS Code commands were not mapped because they are extension-specific, condition-specific, or have no direct Zed equivalent, including Java type hierarchy, VS Code merge-conflict commands, and some debugger REPL actions.
