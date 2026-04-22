---
name: suggest-commit
description: Analyze a conversation and the resulting repository changes, highlight the important work, suggest Conventional Commit messages, optionally copy the chosen message to the clipboard, and optionally create the commit. Use when the user asks for a commit suggestion, commit message, conventional commit, change summary, clipboard-ready commit text, or auto-commit from a conversation.
---

# Suggest Commit

## Workflow

1. Gather evidence from the conversation first: user intent, constraints, decisions, files mentioned, commands run, validation results, and unresolved caveats.
2. Inspect repository state when available with `git status --short`, `git diff --stat`, and targeted diffs. Do not assume the conversation contains every changed file.
3. Separate user-authored or unrelated work from the changes being summarized. If scope is unclear, call it out instead of blending unrelated edits into the recommendation.
4. Highlight the work before suggesting commits. Focus on what changed and why, not every implementation detail.
5. Suggest one primary Conventional Commit message. Add alternatives only when there are genuinely different scopes, types, or split-commit options.
6. If the user asks to copy the message, copy only the selected commit message, not the analysis or highlights.
7. If the user asks to auto-commit, stage only the intended files and run `git commit` with the selected message after confirming the diff scope is clear.

## Output Shape

Prefer this structure:

```md
Highlights:
- [important change, decision, or validation result]
- [important caveat or excluded unrelated change, if relevant]

Suggested commit:
type(scope): imperative summary

Optional body:
[brief why/what detail when the subject line is not enough]
```

Keep the subject line under 72 characters when practical. Use imperative mood and lowercase Conventional Commit types.

## Clipboard Option

When the user asks to copy the recommendation, pipe the final selected message to `scripts/copy_commit_message.sh`:

```bash
printf '%s\n' 'type(scope): imperative summary' | path/to/suggest-commit/scripts/copy_commit_message.sh
```

For a multi-line commit message, copy the subject, a blank line, and the body. Report whether copying succeeded. If no clipboard tool is available, print the message and explain that it was not copied.

## Auto-Commit Option

Only commit when the user explicitly asks for auto-commit, commit it, or equivalent. Before committing:

1. Run `git status --short` and inspect the relevant diff.
2. Identify unrelated modified or untracked files and exclude them unless the user explicitly includes them.
3. Stage only the intended paths.
4. Commit with the selected message. Use multiple `-m` flags for subject and body, or a temporary message file for longer bodies.
5. Report the commit hash and list any remaining unstaged or untracked files.

Do not auto-commit if the intended scope is ambiguous, validation failed in a way that affects the change, or the message would need to include secrets or sensitive details.

## Choosing Type And Scope

Use the narrowest accurate type:

- `feat`: user-facing capability or new workflow
- `fix`: bug fix or behavioral correction
- `docs`: documentation-only change
- `style`: formatting-only change with no behavior impact
- `refactor`: internal restructuring without behavior change
- `perf`: performance improvement
- `test`: tests only
- `build`: build system, dependencies, packaging
- `ci`: CI configuration
- `chore`: maintenance that does not fit the above

Use a scope when it clarifies ownership, such as `feat(zsh): ...`, `docs(nvim): ...`, or `chore(skills): ...`. Omit scope when it would be vague or noisy.

## Split-Commit Guidance

Recommend multiple commits when the diff contains independent changes that would be easier to review or revert separately. For each commit, list:

- included files or behavior
- proposed Conventional Commit subject
- any dependency between commits

Do not invent split commits when the work is cohesive.

## Quality Bar

- Ground suggestions in observable conversation details and diffs.
- Mention validation commands and outcomes when they materially support the commit.
- Flag missing validation as a caveat instead of pretending it happened.
- Avoid exposing secrets or copying sensitive conversation details into commit text.
- If there are no repository changes, provide a conversation-based draft and say it was not verified against a diff.
