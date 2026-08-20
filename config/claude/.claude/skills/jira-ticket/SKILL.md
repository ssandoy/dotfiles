---
name: jira-ticket
description: Reads Jira tickets through the user's local shell helpers and uses them as context for analysis or implementation. Use when the user explicitly asks for help with a Jira issue, asks to read or inspect a ticket, or requests work based on a Jira URL or issue key such as WOW-2483.
---

# Jira Ticket

## Resolve the ticket

1. Look for Jira keys in the conversation, including keys inside URLs containing `/browse/<KEY>`.
2. If exactly one key is present, use it.
3. If multiple keys are present, ask the user which ticket is active.
4. If no key is present, get the current ticket:

   ```bash
   "$HOME/.claude/skills/jira-ticket/scripts/jira-ticket" current
   ```

   Confirm with the user that this is the correct ticket before reading it or doing any work. If there is no current ticket, ask the user for a Jira key or URL.

## Gather context

Read only the fields returned by the existing `jira-view` helper:

```bash
"$HOME/.claude/skills/jira-ticket/scripts/jira-ticket" read <Jira URL or issue key>
```

Use the returned ticket details as context. Do not fetch comments, attachments, linked issues, or additional fields unless the user explicitly asks.

## Start work

Reading or summarizing a ticket does not change `jira-current`.

Before implementation, debugging, or planning:

1. Read the ticket comments:

   ```bash
   "$HOME/.claude/skills/jira-ticket/scripts/jira-ticket" comments <Jira URL or issue key>
   ```

   Treat comments as requirements context because they may clarify or supersede the description. Do not start work until they have been reviewed.

2. Always select the resolved ticket as `jira-current` before doing any work:

   ```bash
   "$HOME/.claude/skills/jira-ticket/scripts/jira-ticket" select <Jira URL or issue key>
   ```

   Do this even if the ticket may already be current. Immediately verify the persisted selection:

   ```bash
   "$HOME/.claude/skills/jira-ticket/scripts/jira-ticket" current
   ```

   The output must exactly match the resolved key. If selection or verification fails, stop and report it rather than continuing. Treat verified selection as a required precondition for continuing.

3. Form a short, intuitive branch description from the ticket's content and comments, then prepare the ticket branch:

   ```bash
   "$HOME/.claude/skills/jira-ticket/scripts/jira-ticket" branch <Jira URL or issue key> <short description>
   ```

   The helper switches to an existing matching local branch, tracks an existing remote branch, or creates `<KEY>-<short-description>` from the updated default branch. If the worktree is dirty or multiple matching branches exist, stop and ask the user how to proceed.

4. Inspect the current repository and perform the requested work using the ticket as requirements.

## Safety

- Use the local helper so authentication remains in the user's existing Atlassian configuration.
- Never expose Atlassian credentials or environment-variable values.
- Do not assign, edit, comment on, or transition a ticket unless the user explicitly requests that mutation.
- `jira-use` only updates the local current-ticket context; it does not authorize any Jira-side mutation.
- Branch preparation must not call `jira-start`, because that helper assigns the ticket.
- If the URL or key is invalid, report the validation error rather than guessing.
- If Jira access fails, report the command error and do not invent ticket contents.

## Examples

- `https://elhub.atlassian.net/browse/WOW-2483`
- `Read WOW-2483 and summarize the expected behavior`
- `Help me implement the Jira ticket WOW-2483`
