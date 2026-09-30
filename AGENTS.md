# phlex-forms

Project instructions for every agent: Claude Code (`CLAUDE.md` imports this file),
Cursor, Copilot, Codex, and any other AI tool working in this repo. Claude Code
users also have `.claude/commands/` and `.claude/rules/` for slash commands and
auto-loaded rules — this file is still the full project brief.

A model-bound form builder for [Phlex](https://www.phlex.fun): `field :email`
renders a label, an input, and an error/hint in one call, inferring the input
type and the `required` flag from the model. DaisyUI-styled by default (via the
[`daisyui`](https://github.com/zoolutions/daisyui) gem) with a Plain (unstyled)
theme fallback, plus optional server-truth live validation over
[phlex-reactive](https://github.com/zoolutions/phlex-reactive). The gem also
**dogfoods a docs site** under `docs/` (built on docs-kit).

## Tech Stack

- **Ruby**: >= 3.4 (aligns with the optional phlex-reactive live integration)
- **Rendering**: Phlex 2 — components live under `Forms::`, internals under `PhlexForms::`
- **Styling**: daisyUI (soft dependency) — leaf components delegate markup + variants to the `daisyui` gem
- **Type inference**: `PhlexForms::Inference` reads columns / enums / associations / validators
- **Live validation**: `Forms::Live` over phlex-reactive (soft dependency)
- **Autoloading**: zeitwerk (two roots: `lib/forms` → `Forms::`, `lib/phlex_forms` → `PhlexForms::`)
- **Testing**: RSpec (unit + integration render specs)
- **Linting**: RuboCop
- **Docs site**: a nested docs-kit app under `docs/` (its own Ruby 4.0.5, its own bundle)

## Critical Rules

### Never Do
1. **NO hardcoded component classes** — leaf components resolve through `PhlexForms::Theme` (role → class), so the same form renders daisy or Plain. Don't reference `Forms::Input` directly where a theme role belongs.
2. **NO interpolated Tailwind/daisy class strings** — write literal class strings (`"input input-primary"`, never `"input-#{x}"`); the host's Tailwind scanner can't see a built name, so the style never ships.
3. **NO unguarded model introspection** — every model touch sits behind `respond_to?` guards + a `StandardError` rescue (see `Forms::Field#required?`, `PhlexForms::Inference`), so plain objects / Structs / untyped ActiveModel degrade to the name map. Inference must never require ActiveRecord.
4. **NO hard dependency on daisyui or phlex-reactive** — both are soft: `require`-rescue-`LoadError` + Zeitwerk `ignore` of the files that reference them. The gem must boot and render (Plain theme) without either.
5. **NO `raw`/`html_safe` on user/model data** — let Phlex escape; only gem-authored trusted markup may bypass it. Field names, choices, values are user-influenced.
6. **NO caller options silently lost** — in `field`, explicit `as:`/`choices:`/caller kwargs always win over inferred attributes.
7. **NO manual `gem push`** — release via `bin/release` (patch/minor/major/explicit; wraps `rake release[X.Y.Z]` in `rakelib/release.rake`, which bumps the version file + the `phlex-forms` pin in every tracked lockfile (docs/Gemfile.lock; the gem root `Gemfile.lock` is gitignored, correct for a library gem). The release files are the zoolutions release kit — never edit them here; change docs-kit and `script/release-kit sync`).

### Always Do
1. **TDD**: write tests BEFORE implementation (RED → GREEN → REFACTOR).
2. **Preserve graceful degradation** — a change to inference/theming must keep POROs and non-daisy hosts working; the existing specs are the regression suite.
3. **Honor both themes** — a new leaf component needs a daisy form AND a `Forms::Plain::*` form that accepts-and-ignores variants, wires `aria-invalid`/`data-field-error`, and ships zero styling classes.
4. **Wire inference, don't special-case** — a new type mapping goes into `PhlexForms::Inference`'s precedence chain, behind guards, with a unit spec in the precedence table.
5. **Config gets a default** — a new `PhlexForms::Configuration` knob has a sensible default so existing apps keep working.
6. **Assert on semantics** — a spec checks `name="user[email]"`, the selected option, the error message — not a brittle full-HTML snapshot.

## Commands

```bash
bundle exec rspec                    # Full suite (unit + integration render specs)
bundle exec rubocop lib spec         # Lint (rubocop -A lib spec to autocorrect)
bundle exec rake                     # spec + rubocop (the default task)
```

The docs site under `docs/` has its own bundle (Ruby 4.0.5): `cd docs && bin/dev`.
Ruby floor is **3.4** (the CI matrix is 3.4 + 4.0).

Command output is condensed by rtk (PreToolUse hook). Write commands in
hook-rewritable shapes: no `for`/subshell wrappers, no `| head` on rtk-handled
commands, `bundle exec rubocop` not `bin/rubocop`.

## Slash Commands

| Command | Purpose |
|---------|---------|
| `/plan` | Fable-powered planning → GitHub issue or `docs/plans/` markdown (read-only; execute with `/lfg`) |
| `/lfg` | Full autonomous workflow: branch → understand → explore → plan → TDD → verify → PR |
| `/tdd` | Enforce RED → GREEN → REFACTOR |
| `/architect` | Coordinate a change across the builder → components → inference → theme → live layers |
| `/security` | Security audit (HTML escaping, model-bound params, the live action whitelist, CSRF) |
| `/review-pr` | Review a PR for pattern compliance |
| `/github-review-pr` | Full PR pass: fix CI failures, then resolve review comments (in that order) |
| `/github-review-failures` | Fix failing CI checks until green |
| `/github-review-comments` | Process unresolved PR review comments |
| `/finish-prs` | Drive a stack of open PRs to merge-ready one at a time |

## Architecture

```
Layer 5: Live validation    lib/forms/live.rb, lib/forms/live/field.rb (phlex-reactive; the :validate action, signed identity, touched tracking) — SOFT dep
Layer 4: Theming            lib/phlex_forms/theme.rb (role → component map), lib/forms/plain/*.rb (bare semantic HTML), daisy leaves are the default
Layer 3: Type inference     lib/phlex_forms/inference.rb (columns/enums/associations/validators → control + attrs, all behind respond_to? guards)
Layer 2: Field components    lib/forms/*.rb (Input, Select, Textarea, Checkbox, Toggle, Radio, FileInput, ...) delegating markup to daisyui via lib/phlex_forms/delegated_field.rb
Layer 1: The builder API    lib/phlex_forms/builder.rb (the `field` verb + PascalCase escape hatches, row/group), lib/forms/form.rb (inline), lib/forms/base.rb (declarative classes), lib/forms/field.rb (per-field context)
Layer 0: Config + engine    lib/phlex_forms/configuration.rb (theme/infer_from_model/field_variants/icon_renderer), lib/phlex_forms.rb (soft-require wiring), lib/phlex_forms/engine.rb (Rails: Stimulus controllers, locales, the live param type)
         Docs site           docs/ (a docs-kit Rails app), deployed via .github/workflows/deploy-docs.yml → docs-kit's reusable workflow
```

## The mental model

> The model already knows. `field :notify` renders a toggle for a boolean
> column, an enum becomes a humanized select, a `belongs_to` a collection
> select — `as:`/`choices:` are overrides, not requirements. The same form
> class renders daisy or Plain by swapping a theme; live validation runs the
> real ActiveModel validators server-side.

Everything is additive and degrades: no ActiveRecord? name-map inference. No
daisyui? Plain theme. No phlex-reactive? the `live` macro raises a clear
`FeatureUnavailable` and the Stimulus `validate: true` fallback still works.

## Model tiers (for Claude Code commands & agents)

**Models.** Sessions run on `opus` (Opus 5.5) with `fable` (Fable 5.1) as the advisor (`.claude/settings.json`). Fable is spent where judgment matters most: `/plan` runs on Fable, the advisor is consulted at decision points (before choosing an approach, a schema or public API, a migration, a dependency, anything irreversible, and when a failure repeats), and the `fable-validator` agent checks every finished implementation before its pull request opens (`/lfg`, Phase 6.5). Commands pin their tier by alias, never by full model ID: `opus` for orchestration, security, full PR review, payments and production debugging; `sonnet` for the implementation specialists and TDD; `haiku` for mechanical scans. Every spawned agent names its `model:`; one that does not runs on `sonnet` (`CLAUDE_CODE_SUBAGENT_MODEL`), never on the session's model. Plan mode cannot take a model of its own: it runs on Opus and asks the advisor.

## Testing

- Unit specs (`spec/phlex_forms/`) cover pure logic with no rendering — `PhlexForms::Inference` (the full precedence table), `PhlexForms::Configuration`, `PhlexForms::Theme`.
- Integration specs (`spec/forms/`) render a real form through a kit-context helper (`render_form(model) { |f| ... }`, see `spec/support/phlex_helpers.rb`) and assert on the produced markup's semantics (`name=`, selected option, error message, the error variant class).
- Model doubles use `build_model` (an anonymous ActiveModel class, `spec/support/model_helpers.rb`) — no database.
- `Forms::Live` specs are guarded by `if defined?(Phlex::Reactive)` and stub the reply (the endpoint isn't booted); a class-level assertion (`skip_verify_authorized?(:validate)`) guards the one behavior specs can't drive.
- Aspire to 100% for `PhlexForms::Inference` / `Configuration` / `Theme` — the public API sites depend on.
- CI: `.github/workflows/main.yml` runs `bundle exec rspec` on Ruby 3.4 + 4.0 for every push to `main` and every PR; lint on 4.0.
- See `.claude/rules/testing.md`.

## Writing a docs page for phlex-forms' own docs site (under `docs/`)

The docs site is a docs-kit site. Its registry is `docs/app/models/doc.rb`; its
pages are `docs/app/views/docs/pages/`. To document a gem feature:

**1. Scaffold** (from the `docs/` app):

```bash
cd docs && bin/rails g docs_kit:page "Type inference" --group=Guide
```

That writes `docs/app/views/docs/pages/type_inference.rb` **and** injects the
`page "Type inference", group: "Guide"` line into `Doc` (no line, no page).
Overrides: `--slug`, `--view`, `--eyebrow`.

**2. Write `#content` — Markdown first.** Prose is `md` with a **single-quoted**
heredoc (`<<~'MD'`) so `#{…}` stays literal. `DocsUI::Section` owns structure and
the TOC — never a Markdown `##` for structure. Positional primary arg, keyword
modifiers: `Section("Title", description:)`, `Code(source, filename:)`. Reference
tables: `DocsUI::Table`, `DocsUI::Callout(:note | :tip | :warning)`. The worked
example of the whole contract is any existing page under
`docs/app/views/docs/pages/` (e.g. `field_api.rb`, `inference.rb`). There is a
`write-docs-page` skill under `docs/.claude/skills/` for this exact task.

**3. Verify**: `cd docs && bundle exec rspec && bundle exec rubocop` (`bun run
build:css` if you added classes the CSS scans).

## Screenshots on PRs and issues (always)

A rendered form or docs page change ships with before/after pictures **on the
PR**, attached from the terminal. Never a local path, a base64 blob, or
"screenshot available on request". Applies to: a `Forms::`/`PhlexForms::`
component's rendered markup (daisy AND Plain theme when both changed), and any
`docs/` page.

`gh` ≥ 2.99 uploads images and videos itself:

```bash
gh pr create --attach './after.png#Sidebar collapsed on mobile' --title … --body …   # picture in hand already
gh pr comment <n> --attach './after.png#Sidebar collapsed on mobile' --body 'Before/after for the error state.'
gh pr comment <n> --attach ./before.png --attach ./after.png   # repeat the flag, up to 50 files
gh issue comment <n> --attach ./repro.mp4                       # video renders as a player
```

- Quote the whole argument: the alt text has spaces and bare `<`/`>` would redirect. `<file>#<alt text>`
  sets the alt text; without it the filename is used. A body that already
  references the file (`![alt](./after.png)`) gets that reference rewritten to the uploaded
  asset, so images can sit inline; unreferenced attachments are appended at the end.
- `create`, `edit` and `comment` all take `--attach` (all three landed in gh 2.99). Attach at create time when
  the picture already exists; comment when it comes later, as it does after a verification run.
- Capture with `agent-browser screenshot <file>` against `docs/` (`cd docs && bin/dev`) or a spec-rendered
  page. Save under the scratchpad, never in the repo.
- No `--attach` flag means an old `gh`: `brew upgrade gh`.

## Release & docs deploy

- `bin/release [patch|minor|major|X.Y.Z]` (`list` / `--dry-run` / `--force`) computes the next version, shows the commits since the last tag, confirms, then runs `rake release[X.Y.Z]`, which bumps the version, verifies `gem build --strict`, pushes, and creates the GitHub release; CI (`release.yml`) tests, builds, signs (Sigstore), and publishes to RubyGems via trusted publishing.
- The docs site deploys on release via `.github/workflows/deploy-docs.yml`, which calls docs-kit's reusable dash + GHCR workflow. `image`/`service` are `zoolutions/phlex-forms`.

## More Documentation

- `.claude/commands/` — slash command definitions
- `.claude/rules/` — coding style, git workflow, testing, agents
- `README.md` — the full field API / inference / theming / live-validation guide
- `docs/` — the published documentation site (docs-kit)
