# dotfiles

## Overview
This repository manages all your configuration files (dotfiles) in a unified, modular, and XDG-compliant way using [GNU Stow](https://www.gnu.org/software/stow/).

- **Application-first organization:** Each tool has its own directory under `config/`
- **XDG compliance:** XDG configs are placed in `.config/<app>/` subdirectories for seamless symlinking
- **Modular stowing:** Each application can be managed independently

## Requirements

- **GNU Stow**: For symlink management (`sudo apt install stow` or `brew install stow`)
- **zsh**: For shell configuration (`sudo apt install zsh`)
- **tmux**: Terminal multiplexer (`sudo apt install tmux`)
- **git**: Version control (`sudo apt install git`)
- **vim**: Text editor (`sudo apt install vim`)
- **mise**: Tool version manager ([see mise docs](https://mise.jdx.dev/getting-started.html))
- ... (see `provision.sh` for the full list)

_Optional:_
- **oh-my-zsh**: For zsh plugin management
- **oh-my-posh**: Prompt theme engine for any shell ([see oh-my-posh docs](https://ohmyposh.dev/docs/installation))

---

## Automated Setup

For first-time setup or provisioning a new machine, simply run:

```sh
sudo ./provision.sh
```

This script will install all required packages and symlink your configs using `stow-all.sh`.

---

## Directory Structure

```
.dotfiles/
├── .stowrc              # Stow configuration (default target, ignore rules)
└── config/              # All configuration files
    ├── tmux/            # Home directory dotfiles
    │   └── .tmux.conf
    ├── zsh/
    │   └── .zshrc
    ├── git/
    │   ├── .gitconfig
    │   └── .git-templates/
    ├── vim/
    │   └── .vimrc
    ├── mise/            # XDG config example
    │   └── .config/
    │       └── mise/
    │           └── mise.toml
    # ... add more as needed
```

---

## Stow Configuration

`.stowrc` in the repo root:
```
--target=$HOME
--ignore=.stowrc
```
This allows you to simply run `stow <package>` from the `config/` directory, and files will be symlinked to the correct locations.

---

## Usage

### 1. Clone and Enter the Repo
```sh
git clone https://github.com/yourusername/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
```

### 2. Provision and Stow All Configurations
```sh
sudo ./provision.sh
```

### 3. (Manual) Stow or Unstow Specific Applications
If you want to stow or unstow a specific application manually:
```sh
cd config
stow tmux
stow -D tmux  # Unstow
```

### 4. Update After Changes
```sh
stow -R tmux
```

---

## XDG Compliance

For XDG-compliant apps, configs are placed in `.config/<app>/` subdirectories inside each package. Stowing from the `config/` directory with `--target=$HOME` will symlink them into `~/.config/<app>/` automatically.

---

## Best Practices
- Keep each application's config in its own directory
- Use dot-prefixed filenames for home directory dotfiles (e.g., `.zshrc`)
- Use `.config/<app>/` for XDG configs
- Document major changes in this README

---

## Example: Adding a New App
1. Create a new directory under `config/` (e.g., `nvim/`)
2. Place your config in `.config/nvim/` inside that directory
3. Run `stow nvim` from `config/`

---

## Troubleshooting
- Ensure you run `stow` from the directory containing `.stowrc`
- Check your stow version (`stow --version`)
- For non-XDG apps, use dotfiles in the package root
- For XDG apps, use `.config/<app>/` structure

---

## License
MIT
