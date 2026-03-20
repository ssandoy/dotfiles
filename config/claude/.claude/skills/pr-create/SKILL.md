---
name: pr-create
description: Runs lint, stages all changes, creates a conventional commit, then opens a PR with gh pr create. Use when the user wants to ship their current changes end-to-end.
---

# Ship It

Run lint, commit everything with a conventional commit message, and create a PR. No user input — proceed autonomously at every step.

## Steps

### 1. Check branch

```bash
git rev-parse --abbrev-ref HEAD
```

If the current branch is `main` or `master`, **abort immediately** and tell the user to create a feature branch first. Do not proceed.

### 2. Run lint

Inspect the project to find how it actually lints — do not assume:

- Check `package.json` `scripts` for a `lint` or `lint:fix` entry and use that exact command
- Check `Makefile` for a `lint` target and use `make lint`
- Check `go.mod` + a `golangci-lint` config (`.golangci.yml` etc.) and use `golangci-lint run`; fall back to `go vet ./...` if only `go.mod` is present
- Check for other explicit lint configs (`.eslintrc*`, `pyproject.toml` with `[tool.ruff]`, etc.) and run the corresponding tool

If no lint command can be identified, skip linting and proceed — the PR will be created as a **draft**.

If lint fails, stop and report the errors to the user — do not commit.

### 3. Stage all changes

```bash
git add -A
```

If there is nothing to commit, skip to step 5.

### 4. Conventional commit

Inspect the staged diff (`git diff --cached --stat`) to infer the right commit type and scope:

| Type | When |
|------|------|
| `feat` | new functionality |
| `fix` | bug fix |
| `chore` | tooling, deps, config, non-functional |
| `refactor` | restructuring without behaviour change |
| `docs` | documentation only |
| `test` | adding or fixing tests |

Format: `<type>(<optional scope>): <short imperative summary>`

Do not ask for confirmation — infer the best message and commit immediately.

```bash
git commit -m "<inferred message>"
```

### 5. Push the branch

Push the current branch to origin (set upstream if not already set):

```bash
git push -u origin HEAD
```

### 6. Create the PR

Use the conventional commit message as the PR title and summarize the changes in the body. Use `--draft` if no linter was found in step 2 or if you are unsure about anything:

```bash
gh pr create --title "<type>(<scope>): <summary>" --body "<description>"
# or if uncertain:
gh pr create --draft --title "<type>(<scope>): <summary>" --body "<description>"
```
