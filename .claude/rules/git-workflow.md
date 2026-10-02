# Git Workflow Rules

## Commit Messages

Use conventional commits:
- `feat:` - New feature
- `fix:` - Bug fix
- `refactor:` - Code refactoring
- `perf:` - Performance improvement
- `docs:` - Documentation only
- `test:` - Adding/updating tests
- `chore:` - Maintenance tasks
- `ci:` - CI/CD changes

Format:
```
feat(scope): brief description

Longer explanation if needed. Focus on WHY, not WHAT.

Refs #123
```

Scopes map to the architecture: `shell`, `sidebar`, `code`, `page`, `theme`,
`registry`, `controller`, `generator`, `engine`, `deploy`, `docs`, `ci`.

## Heredoc bodies — no gratuitous escaping

When writing a commit message or a `gh issue`/`gh pr` body via a single-quoted
heredoc (`<<'EOF'`), the body is copied **verbatim**. Do NOT escape backticks or
pipes — if you would not type a backslash in a GitHub comment, do not type one in
the heredoc. Escaping produces literal backslashes in the rendered Markdown.

## Branch Naming

- `feature/description` - New features
- `fix/description` - Bug fixes
- `refactor/description` - Refactoring
- `ci/description` - CI changes
- `chore/description` - Maintenance

## PR Workflow

All work goes through PRs.

1. Create branch from `main`
2. Make focused, atomic commits
3. Run validators before pushing (`bundle exec rake`)
4. Create PR with summary + test plan
5. Label the PR: exactly one `type` + at least one `area` (`gh pr create --label …`), never a `status` label. `bin/labels infer <changed paths>` gives the areas; the taxonomy is `.github/labels.yml`, the rules are `.github/LABELS.md`
6. Request review
7. Squash merge when approved + CI green

## Release

Releases go through `bin/release` (`bin/release` = patch, `minor`, `major`, or
an explicit `X.Y.Z`; `list` shows recent tags and the next versions, `--dry-run`
previews, `--force` re-cuts an existing tag). It shows the commits since the
last tag, asks for confirmation, then hands off to `rake release[X.Y.Z]` in
`rakelib/release.rake` (bumps version + the tracked lockfile pins, verifies the
build, commits, pushes, creates the GitHub Release). The Release workflow then
publishes to RubyGems. Never `gem push` by hand. `bin/release`,
`rakelib/release.rake` and the shared jobs of `release.yml` are the zoolutions
release kit (canonical copy in docs-kit, see its RELEASE_KIT.md): never edit
them here — change docs-kit, then `script/release-kit sync`.

## Pre-Commit Checklist

Run before EVERY commit:
```bash
bundle exec rubocop   # Style
bundle exec rspec     # Suite
```

## Rules

- **NEVER** commit directly to `main`
- **NEVER** force push to shared branches
- **NEVER** `gem push` manually — use `bin/release` (wraps `rake release[X.Y.Z]`)
- Labels are edited in `.github/labels.yml` and applied with `bin/labels sync`, never by hand in the GitHub UI. `bin/labels` and `.github/LABELS.md` are the zoolutions labels kit (canonical copy in docs-kit, see its LABELS_KIT.md): never edit them here — change docs-kit, then `script/labels-kit sync`
- **ALWAYS** run validators before committing
- **ALWAYS** write meaningful commit messages
- Keep commits small and focused — one logical change per commit
