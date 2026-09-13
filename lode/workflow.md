# Workflow profile

Everything the shared workflow skills (`/lode:lfg`, `/lode:review-pr`,
`/lode:finish-prs`, `/lode:debug-flaky`, `/lode:tdd`, `/lode:plan`) need to know
about phlex-forms that is not already in `CLAUDE.md`, `.claude/rules/` or the
rest of `lode/`.

## Commands

| Purpose | Command | Notes |
|---|---|---|
| fast loop (one file) | `bundle exec rspec spec/<path>_spec.rb` | no network, no database, no services; a unit file runs in well under a second |
| full suite | `bundle exec rspec` | 198 examples, all in-process. Safe to run in two worktrees at once — nothing shared, no ports, no fixture dirs |
| lint | `bundle exec rubocop lib spec` | the CI Lint job's exact invocation, and the only one that works. `bundle exec rubocop -A lib spec` to autocorrect. The two paths are deliberate: `Rakefile`, `bin/` and `*.gemspec` are not linted |
| both, as CI sees them | `bundle exec rspec && bundle exec rubocop lib spec` | **not** `bundle exec rake`. The default task is `spec` then `rubocop`, and `RuboCop::RakeTask` passes no paths, so RuboCop descends into `docs/`, loads `docs/.rubocop.yml` and dies on `cannot load such file -- docs_kit/rubocop` — that gem is in the docs bundle, not the root one. `bundle exec rake` therefore always fails at the lint step, whatever the code says. `CLAUDE.md` and `.claude/rules/git-workflow.md` both still name it as the pre-commit gate |
| one CI cell locally | n/a | the matrix is only Ruby 3.4 and 4.0 running the same two commands; `.tool-versions` pins 4.0.5 |
| docs lint / checks | `cd docs && bin/rubocop`, `cd docs && bin/ci` | separate bundle — `cd docs && bundle install` first. `bin/ci` is `ActiveSupport::ContinuousIntegration` over `docs/config/ci.rb`: setup, rubocop, bundler-audit, `bin/importmap audit`, brakeman. `bundler-audit` and `importmap audit` hit the network |
| docs CSS build | `cd docs && bun run build:css` | wraps `bin/build-css`; needs `bun` and `bundle show` to resolve daisyui, docs-kit and phlex-forms |
| run the app | `cd docs && bin/dev` | execs `bin/rails server` only. It does **not** read `Procfile.dev`, so start `bun run watch:css` in a second shell or the CSS goes stale |
| release | `bin/release [patch\|minor\|major\|X.Y.Z]` (`list`, `--dry-run`, `--force`) | only from `main`, only with a clean tree; wraps `rake release[X.Y.Z]` |

## Branches and PRs

- Default branch: `main`. Remote: `zoolutions/phlex-forms` (public). The `.claude/commands/*` still name `mhenrixon/phlex-forms` — stale, the repo moved.
- Work branches root off fresh `origin/main`. History shows `fix/*`, `chore/*`,
  `feature/*` and `issue-<n>-<slug>`; `.claude/rules/git-workflow.md` lists
  `feature/`, `fix/`, `refactor/`, `ci/`, `chore/`.
- Commits: conventional, with a scope where it helps
  (`fix(file_input): …`, `chore(deploy): …`); the body says why. The scope list
  in `.claude/rules/git-workflow.md` (`shell`, `sidebar`, `page`, `registry`, …)
  is inherited from a docs-site repo and does not match this one — use the layer
  or component name instead.
- PR body sections, in order: Summary, Test plan, Deviations & judgment calls,
  Gate. The Summary must carry a closing keyword per resolved issue —
  `Closes #9, closes #10` — because squash-merge can drop a keyword that lives
  only in a commit body.
- Merge policy: squash on `main` after green and approval (every merge commit on
  `main` carries a `(#N)` suffix). Releases are the one exception: `rake release`
  commits `chore: bump version to X.Y.Z` directly on `main`.
- Never rebase a branch someone else could have pulled; merge `main` forward
  into it instead. `/lode:finish-prs` is the one place a rebase plus
  `--force-with-lease` is used, in a worktree, on a branch only its author has.
- Attribution: no `Co-Authored-By: Claude`, no "Generated with" line.

## Layers

| Layer | Files | Edit rule |
|---|---|---|
| Builder API | `lib/phlex_forms/builder.rb`, `lib/forms/form.rb`, `lib/forms/base.rb`, `lib/forms/fields_for_builder.rb` | owned here; the `field` signature and the ten PascalCase escape hatches are public API — additive only |
| Per-field context | `lib/forms/field.rb`, `lib/forms/live/field.rb` | owned here; every leaf is built from `field_attributes`, never by hand |
| Leaf components | `lib/forms/*.rb` and `lib/forms/plain/*.rb` | owned here; a daisy leaf needs a Plain subclass and both `Theme` maps (`lode/theming/summary.md`) |
| Inference | `lib/phlex_forms/inference.rb` | owned here; a new rule slots into the precedence chain, behind `respond_to?` |
| Theme / merge | `lib/phlex_forms/theme.rb`, `class_merge.rb`, `delegated_field.rb` | owned here |
| Config + boot | `lib/phlex_forms/configuration.rb`, `lib/phlex_forms.rb`, `lib/phlex_forms/engine.rb` | owned here; a new knob needs a default that preserves today's behaviour |
| Stimulus controllers | `app/javascript/phlex_forms/**` | owned here, untested — no JS runner in the repo. Identifiers derive from `Introspector::CONTROLLER_PREFIX`; the file path must match |
| Cops | `lib/rubocop/phlex_forms/**`, `lib/phlex_forms/rubocop.rb`, `config/rubocop.yml` | owned here; opt-in for host apps, Zeitwerk-ignored |
| Docs site | `docs/**` | owned here, separate bundle and RuboCop. Generated: `docs/app/assets/stylesheets/tailwind.sources.css` — edit `bin/build-css`, regenerate; never hand-edit |
| Lockfiles | `docs/Gemfile.lock`, `docs/bun.lock` | committed; regenerate, never hand-merge. The gem's own `Gemfile.lock` is gitignored |

## Shapes

Every change is checked against these before it is called done.

- **A PORO / Struct model** with no `validators_on`, `type_for_attribute`,
  `defined_enums` or `reflect_on_association` — must degrade to the
  attribute-name map, never `NoMethodError`.
- **An ActiveModel form object** (`build_model` in the specs) — attributes and
  validators, no columns, no associations.
- **A `belongs_to` rendered under its foreign key** — the input is
  `country_id`, the errors live on `country`.
- **A `Hash`-backed nested scope** (a JSONB column) versus a genuine collection
  — `fields_for` must not index the Hash.
- **Both themes.** Any leaf change is rendered under `:daisy` and `:plain`.
- **Both soft dependencies absent.** The gem must boot and render with neither
  `daisyui` nor `phlex-reactive` — that is what the Zeitwerk `ignore` list and
  `Theme.reactive_roles` protect.
- **A caller who passed the option explicitly** — `as:`, `choices:`,
  `required:`, `class:`, `multiple:`, a positional modifier: the caller wins
  over anything inferred.
- **`PhlexForms.config.infer_from_model = false`** — model inference off, name
  map still on.
- **Ruby 3.4 and Ruby 4.0**, the two CI cells.
- **A field with no model** (`Form(scope: false)`, a bare kit helper) —
  `field_value` returns nil rather than raising.

## Constraints

Reviewer suggestions that are wrong in this repository.

| Suggestion | Why it is wrong here |
|---|---|
| "Build the class name from the variant" (`"input-#{size}"`) | a host's Tailwind scanner reads the gem's `.rb` files; an interpolated name is invisible and the style never ships |
| "Add `tailwind_merge` for class conflicts" | `PhlexForms::ClassMerge` covers the only three families form fields produce, and the gemspec's four runtime deps are deliberate |
| "Make `daisyui` / `phlex-reactive` a real dependency" | both are soft on purpose; `Theme.plain` and `FeatureUnavailable` are the designed fallbacks |
| "Reference `Forms::Input` directly here" | leaves resolve through `theme[role]` so a theme swap works; a direct reference pins the daisy leaf |
| "Rescue and return nil so it can't blow up" | the introspection paths already rescue to a safe default; a new bare rescue hides the bug instead |
| "Use `glyphs` as the default icon renderer" | rails_icons resolves SVGs from the host's asset tree, which a minimal host has not set up — the inline SVG default is why the gem renders anywhere |
| "Give the checkbox group a `required` attribute" | one array name shared by many boxes; the browser cannot satisfy it. Validate server-side |
| "Run `cd docs && bundle install` to fix the lockfile pin" | `docs/Gemfile.lock`'s broad `PLATFORMS` list makes a full re-resolve fail on most machines; `rake release` string-edits only the `phlex-forms` pin for exactly this reason |
| "Hand-edit `tailwind.sources.css`" | it is generated output; see `lode/review/docs-site.md` |

## Docs

- User-facing docs live in `docs/app/views/docs/pages/` (16 pages, registered in
  `docs/app/models/doc.rb`). The behaviour → page map is in
  `lode/docs-site/summary.md`; the authoring contract is `docs/AGENTS.md` and
  `docs/.claude/skills/write-docs-page/SKILL.md`.
- `README.md` (461 lines) documents the same surface and drifts independently —
  a user-facing change updates it too.
- Changelog: `CHANGELOG.md`, Keep a Changelog. Entries go under the existing
  `### Added` / `### Changed` / `### Fixed` subsection of the target release
  heading — never a second subsection of the same name
  (`lode/review/changelog.md`).
- A change to the `field` API, a theme role, an inference rule, a config knob or
  either cop updates its docs page **and** the changelog in the same PR.
- Files that pin a version and drift after a release: `docs/Gemfile.lock` pins
  `phlex-forms (X.Y.Z)` twice. `rake release` bumps it; if it ever drifts,
  string-edit those two lines rather than re-resolving the bundle.

## CI

- Workflows: `.github/workflows/main.yml` (push to `main` + every PR: `Lint` on
  Ruby 4.0, `Specs (Ruby 3.4)` and `Specs (Ruby 4.0)`, `fail-fast: false`);
  `release.yml` (on a published release: test → build → publish-rubygems →
  upload-release-assets); `deploy-docs.yml` (on a published release or manual
  dispatch, calls docs-kit's reusable `deploy.yml@main`).
- Matrix: Ruby only, `3.4` and `4.0`. A cell differs from a local run only by
  Ruby version — `bundler-cache: true`, nothing else installed.
- Fetch a failure: `gh pr checks <PR>`, then
  `gh run view <RUN_ID> --job=<JOB_ID> --log-failed`.
- "Green" means all three `main.yml` jobs. `Deploy docs` only runs on a release,
  so it is never a PR gate.
- Known not-this-branch failures: none recurring. `Deploy docs` can fail for
  environmental reasons (a missing `docs` environment secret, a registry push)
  without anything being wrong with the branch.
- Shared or rate-limited services the checks hit: none. The gem suite is fully
  in-process, so PRs can run concurrently.

## Flake sources

- **None observed in the gem suite.** No network, no database, no clock, no
  filesystem writes, no sleeps — 198 in-process examples.
- The two real non-determinism surfaces, if one ever appears:
  - **Random order plus global state.** `config.order = :random` with a seeded
    `srand`, and the only automatic cleanup is
    `config.after { PhlexForms.reset_configuration! }`. A spec that mutates
    anything else global — `I18n.locale`, a `Theme` constant, a stubbed
    `Phlex::Reactive.verifier` — leaks in seed order. Reproduce with the failing
    run's `--seed`.
  - **`defined?(Phlex::Reactive)` guards.** Whole files of live and tag-field
    specs are skipped when phlex-reactive is not in the bundle, so a "passing"
    run can have exercised less than another. Check the example count before
    trusting a green run.
- `docs/bin/ci` does hit the network (`bundler-audit`, `bin/importmap audit`); a
  failure there can be an advisory-database update rather than a code change.

## Conflicts

| File | Rule |
|---|---|
| `CHANGELOG.md` | union under **one** heading per category: keep both sides' bullets, drop the duplicate `### Added`/`### Fixed`/`### Changed` subhead. Losing either side's entry is a real regression (`lode/review/changelog.md`) |
| `docs/Gemfile.lock` | never hand-merge. Take the base's file — it carries the released `phlex-forms` pin. If the branch genuinely changed docs dependencies, edit `docs/Gemfile` and re-run `cd docs && bundle install`; if that fails on the `PLATFORMS` list, stop and ask |
| `docs/bun.lock` | take the base's file; if the branch changed `docs/package.json`, re-run `cd docs && bun install` |
| `lib/phlex_forms/version.rb` | releases land directly on `main`, so a feature branch normally never touches it. A conflict here means the branch bumped it deliberately — keep the branch's bump, or ask if the intent is not in its commits |
| `docs/app/models/doc.rb` | append-only registry: keep both `page` lines, base order first |
| `docs/app/assets/stylesheets/tailwind.sources.css` | generated. Take either side, then regenerate with `cd docs && bin/build-css` and verify the three `@source` paths are real |
| `lib/phlex_forms/theme.rb` | both sides usually added a role: keep both entries in **both** the `daisy` and `plain` maps, or the plain path raises `KeyError` at request time |
| the gem's `Gemfile.lock` | cannot conflict — it is gitignored |

## Verification

- The manual check a user of this change would do: `cd docs && bin/dev`, open the
  page under `docs/app/views/docs/pages/` that documents the changed behaviour,
  and read the rendered markup — the docs site renders the real components
  against the real gem through `path: ".."`. For a theme change, look at the
  page under both a light and a dark daisyUI theme via the switcher.
- For a change with no docs page, the check is a spec that renders through
  `render_form` and asserts on the emitted attribute, plus reading the HTML the
  spec produced.
- Stress iterations for a flake proof: 50 runs of the one file with a fresh
  seed each (`bundle exec rspec <file>` in a loop) — the suite is fast enough
  that a real order-dependence shows well inside that.
- Where evidence goes: `lode/tmp/` (gitignored, never committed) unless the PR
  needs an auditable trail. `implementation-notes.md` at the repo root is the
  deviation log during a run; its contents move into the PR body's
  "Deviations & judgment calls" section and the file is then deleted, never
  committed.
