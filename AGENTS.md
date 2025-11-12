# Repository Guidelines

## Project Structure & Module Organization
Configs live under `config/<tool>/` and mirror the destination layout. Home-level dotfiles (e.g., `config/zsh/.zshrc`) sit at the package root, while XDG-aware tools use `.config/<app>/` (such as `config/nvim/.config/nvim/init.lua`). Stow reads `.stowrc` in the repo root, so run it from there or the `config/` directory. Companion scripts (`provision.sh`, `stow-all.sh`) stay at the top level; keep new automation adjacent with executable bits set.

## Build, Test, and Development Commands
- `sudo ./provision.sh`: Installs required packages from `provision.sh` and symlinks everything via `stow-all.sh`; re-run after adding dependencies.
- `./stow-all.sh`: Restows every package; safe to run multiple times.
- `stow <package>` / `stow -D <package>`: Link or remove a single tool; run inside `config/`.
- `stow --simulate <package>`: Dry run to confirm paths before touching `$HOME`.

## Coding Style & Naming Conventions
Prefer descriptive package names that match upstream tool names (e.g., `tmux`, `mise`). File content should respect the tool’s native style (Lua formatting for Neovim, TOML for Mise). Shell scripts use POSIX sh where possible, executable bit set, and `set -euo pipefail` for safety. Maintain two-space indentation inside YAML/TOML, tabs inside Makefiles, and mirror existing comment conventions in each tool’s config.

## Testing Guidelines
Use `stow --simulate` before committing to verify no unintended targets. For shell changes, run `shellcheck` when scripts grow complex. Validate editor or terminal configs by launching the tool with an explicit config flag (`nvim -u config/nvim/.config/nvim/init.lua`, `tmux -f config/tmux/.tmux.conf`). When adding provisioning steps, rerun the script inside a disposable container or VM to ensure idempotence.

## Commit & Pull Request Guidelines
The history follows Conventional Commits (`feat:`, `fix:`, `chore:`). Summaries stay under 72 characters, imperative mood, scoped when helpful (`feat(zsh): add fzf widgets`). Pull requests should explain *why* the change is needed, list impacted tools, note required manual steps (e.g., rerun `stow tmux`), and include before/after screenshots for UI-facing tweaks (polybar, rofi) when practical. Link related issues or provisioning tickets to keep automation traceable.

## Security & Configuration Tips
Never commit machine-specific secrets—store tokens via your password manager and source them from `.local` overrides ignored by git. Double-check file permissions for SSH and GPG assets before stowing; use `chmod 600 config/git/.ssh/*` prior to linking. When adding new brew or apt packages, prefer minimal scopes and document why they are needed in `provision.sh`.
