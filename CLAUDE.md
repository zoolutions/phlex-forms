# phlex-forms

A model-bound form builder for [Phlex](https://www.phlex.fun): `field :email`
renders a label, an input, and an error/hint in one call, inferring the input
type and the `required` flag from the model. DaisyUI-styled by default (via the
[`daisyui`](https://github.com/zoolutions/daisyui) gem) with a Plain (unstyled)
theme fallback, plus optional server-truth live validation over
[phlex-reactive](https://github.com/zoolutions/phlex-reactive).

## Memory

Durable project memory lives in `lode/` (index: `lode/lode-map.md`). Read it
before exploring the code. `lode/review/` holds accepted review findings as
rules about the system; `/lode:gate` enforces them before any push and
`/lode:learn` adds to them. `lode/workflow.md` is the repo profile the shared
`/lode:` workflow commands read. The lode describes the system as it is;
`CHANGELOG.md` records what changed.

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
7. **NO manual `gem push`** — release via `bin/release` (patch/minor/major/explicit; wraps `rake release[X.Y.Z]`, which stages ONLY the version file + the docs lockfile pin; the gem root `Gemfile.lock` is gitignored, correct for a library gem).

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

## Slash Commands

The `/lode:` commands come from the `lode@zoolutions` plugin and read
`lode/workflow.md` for everything repo-specific. The three unprefixed ones are
local to this repo (`.claude/commands/`).

| Command | Purpose |
|---------|---------|
| `/lode:plan` | Read-only planning → GitHub issue or `docs/plans/` markdown (execute with `/lode:lfg`) |
| `/lode:lfg` | Full autonomous workflow: branch → understand → explore → plan → TDD → verify → PR |
| `/lode:tdd` | Enforce RED → GREEN → REFACTOR |
| `/architect` | Coordinate a change across the builder → components → inference → theme → live layers |
| `/security` | Security audit (HTML escaping, model-bound params, the live action whitelist, CSRF) |
| `/review-pr` | Review a PR for pattern compliance |
| `/lode:review-pr` | Full PR pass: resolve conflicts, fix CI failures, then process review comments |
| `/lode:finish-prs` | Drive a stack of open PRs to merge-ready one at a time |
| `/lode:debug-flaky` | Root-cause an intermittent spec — evidence → repro → stress-proofed fix |
| `/lode:gate` | Pre-PR gate: fresh-context review against the rules and `lode/review/`; the push hook requires it |
| `/lode:learn` | Write accepted review findings into `lode/review/` |
| `/lode:sync` | Keep `lode/` true to the code after a change |

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

Commands and agents pin a model **tier** via frontmatter aliases, not a full
model ID — aliases track the latest model in each tier, so pins never go stale:

- `haiku` — mechanical/config work, diff pattern-scans
- `sonnet` — layer specialists / pattern-following implementation
- `opus` — orchestration, security, PR review (`/architect`, `/security`, `/review-pr`)
- `fable` — read-only planning that hands execution to cheaper models; choose it per-session with `/model` for architecture and the hardest debugging

The `/lode:` commands pin their own tiers in the plugin; these three apply to the
local commands under `.claude/commands/`.

When spawning subagents for mechanical work (file finding, pattern scans), pass a
cheaper model explicitly (`model: haiku`) rather than letting them inherit the
session model. See `.claude/rules/agents.md`.

## Testing

- Unit specs (`spec/phlex_forms/`) cover pure logic with no rendering — `PhlexForms::Inference` (the full precedence table), `PhlexForms::Configuration`, `PhlexForms::Theme`.
- Integration specs (`spec/forms/`) render a real form through a kit-context helper (`render_form(model) { |f| ... }`, see `spec/support/phlex_helpers.rb`) and assert on the produced markup's semantics (`name=`, selected option, error message, the error variant class).
- Model doubles use `build_model` (an anonymous ActiveModel class, `spec/support/model_helpers.rb`) — no database.
- `Forms::Live` specs are guarded by `if defined?(Phlex::Reactive)` and stub the reply (the endpoint isn't booted); a class-level assertion (`skip_verify_authorized?(:validate)`) guards the one behavior specs can't drive.
- Aspire to 100% for `PhlexForms::Inference` / `Configuration` / `Theme` — the public API sites depend on.
- CI: `.github/workflows/main.yml` runs `bundle exec rspec` on Ruby 3.4 + 4.0 for every push to `main` and every PR; lint on 4.0.
- See `.claude/rules/testing.md`.

## Release & docs deploy

- `bin/release [patch|minor|major|X.Y.Z]` (`list` / `--dry-run` / `--force`) computes the next version, shows the commits since the last tag, confirms, then runs `rake release[X.Y.Z]`, which bumps the version, verifies `gem build --strict`, pushes, and creates the GitHub release; CI (`release.yml`) tests, builds, signs (Sigstore), and publishes to RubyGems via trusted publishing.
- The docs site deploys on release via `.github/workflows/deploy-docs.yml`, which calls docs-kit's reusable dash + GHCR workflow. `image`/`service` are `zoolutions/phlex-forms`.

## More Documentation

- `lode/` — durable project memory (start at `lode/lode-map.md`)
- `.claude/commands/` — the repo's own slash commands (`/architect`, `/security`, `/review-pr`)
- `.claude/rules/` — coding style, git workflow, testing, agents
- `README.md` — the full field API / inference / theming / live-validation guide
- `docs/` — the published documentation site (docs-kit)
