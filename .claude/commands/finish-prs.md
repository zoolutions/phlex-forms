---
description: "Drive a set of open PRs to merge-ready, one at a time, in a given order. Auto-resolves the recurring CHANGELOG [Unreleased] conflict, runs /github-review-pr (CI failures then review comments) on each, then waits for the user to merge before rebasing and advancing to the next. Use to clear a stack of stacked/parallel PRs without manual rebase churn."
model: opus
argument-hint: "ordered PR list (e.g. '292 288 289 293 294 295'); optional 'automerge' to merge each PR once every check is green (no gh auto-merge); empty = auto-discover your open PRs"
allowed-tools: Bash(gh pr list:*), Bash(gh pr view:*), Bash(gh pr checks:*), Bash(gh pr diff:*), Bash(gh pr comment:*), Bash(gh pr merge:*), Bash(gh api:*), Bash(gh run view:*), Bash(git:*), Bash(bundle:*), Bash(bundle exec:*), Bash(cd:*), Read, Write, Edit, Glob, Grep, Agent, Skill, TaskCreate, TaskUpdate, TaskGet, TaskList, ScheduleWakeup
---

# Finish PRs (ordered merge-ready loop): $ARGUMENTS

You are driving a set of open pull requests to **merge-ready** state, one at a time, in a defined order, minimizing the manual rebase/CI back-and-forth that stacked or parallel PRs create.

The one thing that makes a batch of PRs churn on this repo is **recurring and mechanical**, so this command resolves it automatically instead of surfacing it to the user each time:

1. **CHANGELOG `[Unreleased]` conflicts** — every PR appends an entry under the same section, so each merge re-conflicts the rest. The resolution is always a *union at a known anchor* (`### Added` / `### Fixed` / `### Changed` / `### Removed` / `### Breaking Changes`).

**This command does NOT merge PRs itself** unless the user passed `automerge`. `main` requires 0 reviews, but the user typically wants to eyeball each merge. Default behavior: make each PR merge-ready, then pause and let the user merge; when a merge lands, rebase the remaining PRs and continue.

---

## Phase 0: Parse the PR list and order

`$ARGUMENTS` may be:

- A space/comma-separated ordered list of PR numbers: `292 288 289 293 294 295` (also accepts `#292`, `PR292`).
- The word `automerge` anywhere in the args → this command merges each PR itself (2e) once EVERY check has finished green, with a plain `gh pr merge <PR> --squash` (never `--auto`). Strip it out before parsing numbers.
- Empty → auto-discover: `gh pr list --author=@me --state=open --limit 100 --json number,title,headRefName,createdAt` and order **oldest-first** (`createdAt` ascending). The explicit `--limit` matters — `gh pr list` defaults to 30, so without it the discovery silently drops older PRs once the queue grows past 30. Oldest-first is the safe default: the earliest PR is usually the base others were cut from, so merging it first minimizes downstream rebases. Show the discovered order and proceed.

**Order matters.** Each merge invalidates the others' merge base. Processing in a fixed order means you rebase each remaining PR exactly once per upstream merge, not repeatedly. If the user gave an explicit order, honor it exactly — they may know a dependency the metadata doesn't show.

Create a task list (TaskCreate) with one task per PR, in order, so progress is visible. Mark the current PR `in_progress`.

Confirm the plan in one line: `Finishing N PRs in order: #a → #b → #c. Mode: <pause-for-merge | automerge>.`

---

## Phase 1: Locate each PR's working tree

For each PR you need a checkout of its branch to rebase and push. Prefer, in order:

1. An existing worktree already on that branch: `git worktree list` — match the branch. (Parallel-agent runs leave worktrees under `.claude/worktrees/agent-*`.)
2. If none, create one: `git worktree add .claude/worktrees/finish-<PR> <branch>` (fetch the branch first: `git fetch origin <branch>`).

Never rebase a branch that is currently checked out in the **main working directory** — operate in a worktree so the user's main checkout is undisturbed. Never touch `main` directly.

---

## Phase 2: Per-PR loop

Process PRs strictly in order. For the current PR:

### 2a. Sync onto latest main (rebase, auto-resolving the known CHANGELOG conflict)

```bash
git fetch origin main --quiet
cd <worktree>
git rebase origin/main
```

If the rebase stops on a conflict:

- **`CHANGELOG.md`** — resolve as a union. The conflict is diff3-shaped at the top of an `### <Category>` list: `main`'s entries on the HEAD side, this branch's new entry on the other. Keep **both**, in a sensible order (feature/fix entries before the pre-existing docs-site entry; this branch's own entry adjacent to the others in its category). Practically, for the common "both sides insert at the same anchor" case, strip the markers keeping both blocks:

  ```bash
  perl -0pi -e 's/^<<<<<<< HEAD\n//mg; s/^\|\|\|\|\|\|\| [^\n]*\n=======\n//mg; s/^>>>>>>> [^\n]*\n//mg;' CHANGELOG.md
  ```

  Then **read the result** and verify: no conflict markers remain (`grep -n '^<<<<<<<\|^=======\|^>>>>>>>\|^|||||||' CHANGELOG.md`), this PR's `Refs #<n>` entry is present exactly once, ordering reads cleanly, and no unrelated entry was dropped or duplicated. The perl is a fast path, not a substitute for reading — if the conflict is not the simple same-anchor shape, resolve it by hand.

- **Any other conflicted file** — this command's auto-resolution covers only the one known-mechanical file. For anything else, STOP the rebase (`git rebase --abort`), report the conflicted file(s) to the user, and ask how to proceed. Do not guess at semantic conflicts.

`git add` the resolved files and `git rebase --continue` (set `GIT_EDITOR=true` to accept the message). Repeat until the rebase completes.

### 2b. Push the rebased branch

```bash
git push --force-with-lease origin <branch>
```

`--force-with-lease` (never bare `--force`) so a concurrent push from the user aborts the overwrite instead of clobbering it.

### 2c. Run the full review pass

Invoke `/github-review-pr <PR>` (via the Skill tool). It runs **CI failures first, then review comments** — do not re-implement its logic. It will:

- Fix any red CI checks (lint, specs, build) and push.
- Address every unresolved review thread (CodeRabbit or human): implement valid fixes, push back with reasoning on wrong ones, resolve threads.

Wait for it to finish. If it reports a persistent failure it could not fix (or a review thread it could not resolve without a decision), surface that to the user for this PR and move it to a `needs-user` state — do not block the whole queue on one stuck PR; note it and continue to the next PR, then return.

### 2d. Verify merge-ready

```bash
gh pr view <PR> --json mergeable,mergeStateStatus,reviewDecision --jq '{mergeable,mergeStateStatus,reviewDecision}'
gh pr checks <PR>
```

Merge-ready means: `mergeable=MERGEABLE`, no failing checks (2e waits for the pending ones before any merge), and `reviewDecision` is `APPROVED` or empty (not `CHANGES_REQUESTED`). A `BLOCKED` mergeStateStatus with everything else green usually means "awaiting required approval" — that is expected and fine; it is the user's/reviewer's gate, not a defect.

### 2e. Hand off for merge

Run the `fable-validator` agent on the combined diff first. On BLOCK do not open or merge: mark it `needs-user` and report the blockers instead of calling it ready.

- **`automerge` mode:** only once every check is green. `main` requires only Specs (Ruby 3.4), Specs (Ruby 4.0), Lint and cubic, so GitHub's "mergeable" says nothing about the other checks. Run `gh pr checks <PR> --json name,bucket`: EVERY check in bucket `pass` or `skipping`; any `pending` means wait (`ScheduleWakeup`) and ask again; any `fail` or `cancel` goes back to 2c. Ask again right before the merge (a push while the validator ran leaves checks pending), then a plain `gh pr merge <PR> --squash` (this repo requires linear history; never `--auto`, which would merge on the required checks alone). Then go to Phase 3 to wait for the merge to land before advancing.
- **Default (pause) mode:** report this PR as ✅ merge-ready with its URL and a one-line "what's in it," and tell the user it's ready to merge. Then **wait** (Phase 3).

Mark the PR's task `completed` (merge-ready) — or `needs-user` via a metadata note if it got stuck in 2c.

---

## Phase 3: Wait for the merge, then advance

The loop is **gated on the target PR merging**, because each merge is what invalidates the next PR's base.

- **automerge mode:** poll `gh pr view <PR> --json state --jq .state` until `MERGED`. Use `ScheduleWakeup` with a delay matched to CI duration (this repo's checks run ~1–3 min; poll ~180s, staying inside the prompt-cache window) rather than a busy sleep. When merged, advance.
- **default mode:** the user merges manually and will tell you (or you are re-invoked). On the next turn, re-check `gh pr view <PR> --json state`. If `MERGED`, advance to the next PR in the list and repeat Phase 2 (its rebase now picks up the just-merged changes). If not yet merged, report current status and stop — do not spin.

When you advance, **always re-fetch and rebase the next PR onto the new main** (Phase 2a) before doing anything else — the merge that just landed is exactly the change it needs to absorb.

If the user merges a PR **out of the planned order**, adapt: drop it from the remaining list and rebase whatever is now next.

---

## Phase 4: Final report

When the queue is drained (all merged, or all merge-ready-and-handed-off, or blocked-on-user):

| PR | Result | Note |
|----|--------|------|
| #a | ✅ merged / ✅ merge-ready / ⏳ awaiting-merge / ⚠️ needs-user | one line |

Then: what the user must do next (merge the ready ones, decide on any `needs-user` items), and whether the recurring CHANGELOG conflict is worth fixing at the source.

---

## Important notes

- **Never bare `git push --force`** — always `--force-with-lease`.
- **Never rebase the branch checked out in the main working directory** — use a worktree.
- **Never auto-resolve a conflict outside the one known-mechanical file** (`CHANGELOG.md`). Stop and ask.
- **Never merge in default mode** — the user merges; you make ready and wait.
- **Don't re-implement `/github-review-pr`, `/github-review-failures`, or `/github-review-comments`** — invoke them.
- **One stuck PR must not block the rest** — mark it `needs-user`, continue the queue, return to it in the final report.
- **Read every auto-resolved CHANGELOG** before pushing — the perl fast-path is not a substitute for verifying the entry survived and reads correctly.
