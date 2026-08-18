# dotfiles

## Overview

This repository manages configuration files in a unified, modular, and
XDG-compliant way using [GNU Stow](https://www.gnu.org/software/stow/).
Packages live under `config/<tool>/` and mirror their target paths below
`$HOME`.

- **Application-first organization:** each tool has its own directory under
  `config/`
- **XDG compliance:** XDG configs live in `.config/<app>/` subdirectories for
  seamless symlinking
- **Modular stowing:** each application can be managed independently

## Setup

On Linux, run provisioning as root so it can install system packages:

```sh
sudo ./provision.sh
```

It installs system packages as root, then returns to the invoking user for
submodules, Stow, Oh My Posh, and tmux plugins. This prevents links or
user-owned state from being created under `/root`.

Provisioning updates apt metadata but does not perform a full system upgrade.
Opt in when needed:

```sh
sudo DOTFILES_APT_UPGRADE=1 ./provision.sh
```

On macOS, run it without `sudo` — Homebrew refuses to install as root:

```sh
./provision.sh
```

Inspect every Stow package without changing `$HOME`:

```sh
./stow-all.sh --simulate
```

The script preflights the complete package set before changing anything and
keeps target configuration directories real with `--no-folding`. Applications
can therefore write runtime state without sending it back into this repository.

For a single package, use explicit paths:

```sh
stow --dir=config --target="$HOME" tmux
stow --dir=config --target="$HOME" -D tmux
stow --dir=config --target="$HOME" -R tmux
```

## Directory Structure

```text
.
├── .stowrc              # Stow configuration (default target, ignore rules)
├── provision.sh
├── stow-all.sh
├── lib/platform.sh
└── config/               # All configuration files
    ├── tmux/
    │   ├── .config/tmux/
    │   └── configure-windows-terminal.sh
    ├── zsh/.config/zsh/
    ├── mise/.config/mise/   # XDG config example
    └── <tool>/...
```

## Stow Configuration

`.stowrc` in the repo root:

```text
--target=$HOME
--ignore=.stowrc
```

This lets you run `stow <package>` directly from `config/`. `stow-all.sh`
additionally passes `--no-folding` explicitly, so application runtime state
never gets symlinked into this repository — see "Runtime state and local
overrides" below.

## XDG Compliance

For XDG-compliant apps, configs live in `.config/<app>/` subdirectories inside
each package. Stowing from `config/` with `--target=$HOME` symlinks them into
`~/.config/<app>/` automatically.

## Best Practices

- Keep each application's config in its own directory
- Use dot-prefixed filenames for home directory dotfiles (e.g., `.zshrc`)
- Use `.config/<app>/` for XDG configs
- Document major changes in this README
- Run `gitleaks dir --redact .` before committing local file changes
- Run `gitleaks git --redact .` before pushing history

## Example: Adding a New App

1. Create a new directory under `config/` (e.g., `nvim/`)
2. Place your config in `.config/nvim/` inside that directory
3. Run `stow nvim` from `config/`

## Runtime state and local overrides

Stow manages configuration; application-generated credentials, databases,
caches, and sessions stay local.

- ACLI runtime and authentication YAML lives in the real `~/.config/acli/`
  directory. Only `env` and `env.example` are stowed.
- Codex and Claude Code runtime data (credentials, sessions, caches) lives in
  real `~/.codex/` and `~/.claude/` directories, not in this repository. Each
  package's `.stow-local-ignore` restricts stowing to the files this repo
  actually tracks.
- Machine-specific Git identity and credentials belong in
  `~/.gitconfig.local`, which the tracked Git config includes.
- Never commit secrets. Run `gitleaks dir --redact .` before committing and
  `gitleaks git --redact .` before pushing history. `.gitleaks.toml` excludes
  only VS Code keyboard shortcut `key` fields that resemble generic API keys.

## Ubuntu 26.04 on WSL2

This setup has been validated on Ubuntu 26.04 under WSL2.

- Snap, X11, fonts, and Linux desktop packages are skipped under WSL.
- ACLI installs from Atlassian's signed apt repository.
- Oh My Posh installs into `~/.local/bin`; the prompt falls back to a plain
  zsh prompt if the binary or theme is unavailable.
- `chsh` does not alter an already-open terminal. Run `exec zsh -l` or
  restart Windows Terminal after the first provision.

### Windows font and colors

Install a Meslo Nerd Font on Windows using the
[Oh My Posh font instructions](https://ohmyposh.dev/docs/installation/fonts),
then select it under **Windows Terminal → Ubuntu-26.04 → Appearance → Font
face**. The current host uses `MesloLGS Nerd Font`.

Apply the matching Catppuccin Mocha palette, tab theme, and tmux key
pass-through configuration:

```sh
./config/tmux/configure-windows-terminal.sh --simulate
./config/tmux/configure-windows-terminal.sh
```

Use `--profile NAME` or `--settings PATH` if discovery needs an override.

| Shortcut | tmux action |
| --- | --- |
| `Ctrl+Tab` / `Ctrl+Shift+Tab` | Open the session browser |
| `Ctrl+S` | Split vertically |
| `Ctrl+T` | Split horizontally |
| `Ctrl+W` | Close the current pane |
| `Ctrl+Shift+Q` | Close the current session |

## Jira helpers

Jira functions use configured REST credentials first and fall back to ACLI.
`jira-use`/`jira-pickup` select a ticket via `fzf` and persist it as the
current ticket in `~/.local/state/jira/context.json`, taking precedence over a
branch-derived key; `jira-clear` resets that. See
`config/zsh/.config/zsh/eager/25-jira-workflow.zsh` for the full command list.

Provisioning installs ACLI but does not create credentials. Authenticate with:

```sh
acli jira auth login
```

or put `ATLASSIAN_SITE`, `ATLASSIAN_EMAIL`, and `ATLASSIAN_API_TOKEN` in the
untracked `~/.config/acli/env.local` and run `acli-jira-login`.

## Troubleshooting

- Ensure you run `stow` from the directory containing `.stowrc`.
- Run `./stow-all.sh --simulate` first for a complete conflict report, and
  always run it as your normal user, never with `sudo`.
- For non-XDG apps, use dotfiles in the package root; for XDG apps, use
  `.config/<app>/`.
- If Bash login commands print `bind: warning: line editing not enabled`, an
  unmanaged `~/.profile` is calling Bash `bind` without checking `[ -t 0 ]`.
  It does not affect zsh.
- If tmux is unstyled, verify
  `~/.local/share/tmux/plugins/catppuccin/tmux/catppuccin.tmux` and
  `~/.local/share/tmux/plugins/tpm/tpm`, then rerun provisioning.
- Reload tmux with `prefix` + `R`. The config resets Catppuccin's cached
  global colors before reapplying Mocha, so reloads do not retain an older
  flavor.
- On WSL, GitHub CLI and `jira-open` use the tracked `wsl-browser` bridge as
  `GH_BROWSER`, normalizing `explorer.exe`'s misleading exit code.
- Validate shell changes with `bash -n`, `zsh -n`, and ShellCheck. Validate
  package layout with Stow simulation before committing.

## Contributing

Contributor conventions are in [AGENTS.md](AGENTS.md).

## License

MIT
