---
name: herdr-worktree
description: Create a Git worktree as a Herdr workspace and continue the current agent or start a fresh one there. Use when the user asks to hand off, fork, or isolate current work in a worktree. Requires the agent to be running inside Herdr.
---

# Herdr Worktree

Create the worktree through the existing dotfiles helper; do not duplicate its
Git or Herdr orchestration.

1. Verify `HERDR_ENV=1` and `HERDR_PANE_ID` are both set. If either is missing,
   explain that agent handoff requires a Herdr-managed pane and stop.
2. Confirm the current working directory belongs to the repository the user
   intends to isolate.
3. Choose a short, descriptive branch name from the task when the user did not
   supply one. Use a Git-safe kebab-case name and preserve an explicitly given
   name.
4. Summarize the active task, decisions, changed files, validation, and
   unfinished work in concise handoff context when continuing it. Then run:

   ```bash
   "$HOME/.config/herdr/herdr-worktree" \
     --handoff-agent \
     --context "$handoff_summary" \
     "$branch"
   ```

   This creates and focuses the Herdr workspace, adds its Agents, Diff, and Run
   tabs, starts the same kind of agent in the Agents pane, and prompts it to
   continue with the handoff context. For Codex, the helper forks the native
   session when Herdr exposes its session ID; other agents start a fresh
   session with the supplied context.
   If the user requests a new conversation, use `--fresh-agent "$branch"`
   instead. This starts the same agent kind with no inherited conversation or
   automatic prompt.
5. After a successful handoff, make no further repository changes in the
   source conversation. Report the branch and that the original session
   remains available as a fallback.

Do not launch the helper without a branch from an agent: that opens the
interactive fzf picker. Do not terminate or resume the source session during a
handoff; it remains available as a fallback.

In the `prefix+alt+w` picker, Enter continues the originating agent and
Ctrl-N starts a fresh one. When a worktree already has an agent, either key
focuses it. Codex can fork its session; other agents receive a generic
continuation prompt from the picker, so invoke this skill to pass a useful
task summary for them.
