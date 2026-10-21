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
   ISSUE_LABEL=autopilot      # only issues with this label get an agent; empty = all
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

## Jira

A second source for Jira tickets assigned to the user, across all their clones (in `CLONES_DIR`, default `~/git`) of the GitHub org `GITHUB_ORG` (required in the config). One watcher, started with `autopilot jira` (zsh) from inside herdr or with `prefix+alt+j` (herdr-jira: a dedicated "Jira" workspace, relaunched after herdr restarts; `prefix+shift+j` makes it poll now); config `~/.config/issue-autopilot/jira.env` (`SOURCE=jira`, `GITHUB_ORG=…`; created on first use with an empty `GITHUB_ORG` to fill in; optional `DOMAIN_TERMS` gives `repo-summarize` example terms).

- `jira-tick` polls `JQL` (default: assigned to me, status New/Backlog/To Do) every `JIRA_INTERVAL`. The first run only marks current tickets as seen.
- `repo-picker` asks TypeSafe Jev (`TYPESAFE_API_KEY` in `~/.config/typesafe/env.local`) one yes/no question per repo in `CLONES_DIR` with origin on `GITHUB_ORG`, described by README, GitHub description and folders (`repo-index`); the ticket side includes its Jira components (one `workitem view` per ticket, since search cannot return them). Every repo with probability ≥ `REPO_THRESHOLD` (max `MAX_REPOS`) gets an agent via `jira-spawn`. If none qualifies, uncloned org repos are ranked and the result is only a notification: nothing is cloned.
- `AGENT=copilot` in the config starts interactive Copilot (`copilot -i`) instead of Claude; `AUTONOMY=implement` stops before any commit, push or PR.
- After the first agent starts, the ticket is moved to In Progress with the zsh helper `jira-in-progress`.
- No PR feedback forwarding or cleanup: colleagues review, and the agent stops once its draft PR is open.
- Fix a badly described repo with a line `repo<TAB>description` in `~/.config/issue-autopilot/jira-repos.tsv`.
- State: `~/.cache/issue-autopilot/jira/` (`seen-tickets`, `worktrees.tsv`, `routes.log` with every probability, repo caches). Retry a ticket by removing it from `seen-tickets`, or run `autopilot jira spawn <KEY> [repo]`.
- Tests: `tests/run` (stubs only, no network). `tests/repo-picker-eval` checks routing against real tickets.
