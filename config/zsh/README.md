# Zsh layout

Modular, XDG-first zsh config split into eager (startup-critical) and lazy (deferred) scripts. `.zshrc` lives at `config/zsh/.config/zsh/.zshrc`; it exports XDG vars, sources eager scripts in numeric order, and defers lazy scripts via `zsh_defer` to run on first prompt.

## Structure

- `config/zsh/.zshenv` — sets `ZDOTDIR` to `~/.config/zsh`.
- `config/zsh/.config/zsh/.zshrc` — minimal loader (interactive guard, XDG exports, eager load, deferred lazy load).
- `config/zsh/.config/zsh/eager/` — startup-critical scripts, ordered by `NN-name.zsh`:
  - `00-core.zsh` — stty/lesspipe, editor env.
  - `05-history.zsh` — history file/options.
  - `15-defer.zsh` — zsh-defer plugin bootstrap (submodule).
  - `10-editing.zsh`, `11-keybindings.zsh` — line editing and binds.
  - `20-aliases.zsh`, `21-git-aliases.zsh`, `22-gh.zsh`, `23-kubectl.zsh` — common aliases.
  - `30-functions.zsh` — misc helpers (e.g., `cdr`).
- `config/zsh/.config/zsh/lazy/` — deferred scripts, ordered by `NN-name.zsh` and loaded via `zsh_defer` after the prompt:
  - `40-plugins.zsh` — zinit + plugins.
  - `41-completion.zsh` — compinit with cache.
  - `45-mise.zsh` — mise activation, deferred completion.
  - `50-tools.zsh` — prompt/zoxide/fzf bindings/ssh-agent.
  - `52-fzf.zsh` — fzf helper functions and bindings.
  - `53-fzf-update.zsh` — deferred refresh of fzf install script for keybindings/completions.
  - `55-updates.zsh` — update reminders and helpers.
  - `60-elhub.zsh` — env setup for Elhub contexts.
- `config/zsh/.config/zsh/plugins/` — git submodules for plugins (e.g., zsh-defer).

## Adding files

1) Pick eager vs lazy:
   - Eager: aliases, keybindings, light env that must exist before prompt.
   - Lazy: heavy plugins, completions, large functions; must tolerate running after prompt.
2) Create `NN-name.zsh` with a unique numeric prefix; keep numbering in sequence to control order.
3) For lazy scripts, use `zsh_defer` inside if you further want work to happen after load.
4) Run `stow --simulate zsh` from `config/` to confirm targets, then open a new shell to test.

## Notes

- `zsh -n config/zsh/.config/zsh/.zshrc` lint check.
- XDG cache/data/state defaults are set in `.zshrc`; use them for paths.

## Plugins

- Plugins live under `config/zsh/.config/zsh/plugins/` as git submodules to keep updates clean.
- Current plugin: `zsh-defer` (submodule at `config/zsh/.config/zsh/plugins/zsh-defer`), loaded eagerly via `eager/15-defer.zsh` and used to defer lazy scripts.
- Add a plugin: `git submodule add https://github.com/username/plugin.git config/zsh/.config/zsh/plugins/plugin-name`.
- Update plugins: `git submodule update --remote` (or target one path).
- Best practice: use `zsh-defer` for heavy plugins; keep config separate from plugin checkout and document any custom setup.
