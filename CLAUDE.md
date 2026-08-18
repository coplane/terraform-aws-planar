# Agent Instructions for terraform-aws-planar

This repo uses squash merges. The PR title becomes the commit subject on `main`.

## Required PR title format

Use a conventional title:

`<type>(<optional-scope>): <short imperative summary>`

Allowed `type` values:
- `feat`
- `fix`
- `docs`
- `chore`
- `refactor`
- `perf`
- `test`
- `build`
- `ci`
- `revert`

Examples:
- `feat: add release automation for module tags`
- `fix: stop ignoring ECS service task definition changes`
- `ci: enforce semantic PR titles`
- `docs: clarify BYOC and hosted usage`

Breaking changes:
- Use `!` after type/scope, for example: `feat!: change module input contract`
- Include a clear description of the impact in the PR body.

## Commit messages and PR titles

Use conventional commit format for both commit messages and PR titles. PR title format is enforced in CI and is the source of truth for release notes/versioning. Always include the `<type>:` prefix — PRs will fail CI without it.

## Release automation

`release-please` determines version bumps/changelog entries from squash-merge commit subjects (PR titles). Choose the type carefully:
- `fix` -> patch
- `feat` -> minor
- `!` / breaking change -> major
