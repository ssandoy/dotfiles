---
name: issue-autopilot
description: Sets up an autopilot that watches a GitHub repo's open issues, spawns a herdr worktree workspace with a Claude agent per issue that implements it and opens a draft PR, and forwards PR review comments back to that agent. Use when the user wants issues auto-fixed/auto-implemented, wants to "watch issues and start worktrees", or wants to start, stop or tweak the issue autopilot for a repo.
---

# Issue autopilot

Runs entirely in shell inside herdr (no Claude cron, no token cost while idle):

- `autopilot-watcher` loops in an `Autopilot` tab of the current herdr workspace (the one autopilot-start is run from; falls back to the repo's workspace only outside herdr): every `ISSUE_INTERVAL` it runs `autopilot-tick`, every `FEEDBACK_INTERVAL` it runs `autopilot-feedback` and `autopilot-cleanup`.
- `autopilot-spawn` creates `<ROOT>/.worktrees/issue-<n>-<slug>` via `herdr worktree create --no-focus`, labelled `#<n> <first words of title>`, with Agents/Diff/Run tabs, and starts `claude --permission-mode $PERMISSION_MODE` with the issue as task.
- `autopilot-feedback` forwards new PR comments/inline/review comments to the claude pane in that worktree. Bot accounts and comments starting with 🤖 (agent replies — agents post as the user) are skipped.
- `autopilot-cleanup` removes the worktree, closes its workspace (stopping the agent) and deletes the local branch once its PR is merged or closed. Never forces: a worktree with uncommitted/untracked files or commits beyond the PR head is kept and reported once (state in `cleanup-kept`).

Scripts live in `scripts/` next to this file (call them by absolute path). State: `~/.cache/issue-autopilot/<owner>-<repo>/{seen-issues,forwarded-comments}`.

## Setup workflow

Must be run from inside herdr (`HERDR_ENV=1`).

1. Determine repo (`gh repo view --json nameWithOwner`) and root (`git rev-parse --show-toplevel`).
2. If `~/.config/issue-autopilot/<owner>-<repo>.env` doesn't exist, ask the user (AskUserQuestion, one round):
   - Autonomy: `draft-pr` (default) / `implement` (stop for review) / `plan` (plan, then wait)
   - Which currently open issues to start now (the rest get written to `seen-issues`)
   - Anything to ignore besides Dependency Dashboard
   Pull repo-specific agent rules (commit wrappers, migration policy, etc.) from memory/CLAUDE.md into `COMMIT_WRAPPER` / `EXTRA_RULES` rather than asking.
3. Write the config:
   ```sh
   REPO=Owner/repo
   ROOT=/abs/path/to/repo
   AUTONOMY=draft-pr
   PERMISSION_MODE=auto
   BASE=main
   IGNORE_TITLE_REGEX='^Dependency Dashboard$'
   COMMIT_WRAPPER=''          # e.g. 'mise exec pnpm@12.6.0 --'
   EXTRA_RULES=''             # extra bullet lines appended to every agent prompt
   ISSUE_INTERVAL=600
   FEEDBACK_INTERVAL=300
   ```
4. Seed `seen-issues` with issue numbers the user did NOT pick, then spawn picked ones: `scripts/autopilot-spawn <config> <n>`.
5. Start the watcher from the current herdr pane: `scripts/autopilot-start <config>` — it always goes in an `Autopilot` tab of the current workspace.
6. Report: workspaces spawned, watcher workspace, how to start/skip issues manually.

## Operations

- Start an issue now: `scripts/autopilot-spawn <config> <n>`
- Skip an issue: append its number to `seen-issues`. Re-enable: remove it.
- Stop: close the `Autopilot` tab in the workspace it was started from. Restart: `scripts/autopilot-start <config>`.
- Change behaviour: edit the config, then restart the watcher. Already-running agents keep their original prompt; send them a note with `herdr pane send-text <pane> "..."` + `herdr pane send-keys <pane> Enter`.

## Agent conventions (baked into the spawn prompt)

Short Conventional Commits referencing the issue (`(#n)`), concise draft PR with `Closes #n`, no Co-Authored-By, ask instead of guessing on ambiguous issues, stay in session for forwarded feedback, prefix GitHub replies with 🤖.
