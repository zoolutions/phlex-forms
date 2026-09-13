# AGENTS.md

Guidance for AI coding agents working in the **phlex-forms** repository. This is
the cross-tool convention file (Claude Code, Cursor, Copilot, Aider, …). Claude
Code users also have `.claude/commands/` and `.claude/rules/`; see `CLAUDE.md`
for the full project brief. This file is the fast orientation.

phlex-forms is a model-bound form builder for [Phlex](https://www.phlex.fun):
`field :email` renders label + input + error/hint in one call, with the input
type and `required` flag inferred from the model. It's DaisyUI-styled by default
with a Plain (unstyled) theme fallback, and offers optional server-truth live
validation over phlex-reactive. The gem also **dogfoods a docs site** under
`docs/` (built on docs-kit).

## Memory

Durable project memory lives in `lode/` (index: `lode/lode-map.md`). Read it
before exploring the code. `lode/review/` holds accepted review findings as
rules about the system; `/lode:gate` enforces them before any push and
`/lode:learn` adds to them.

## The two things you'll be asked to do

### A. Change the gem (a component, inference rule, theme, config, the live layer)

Read `CLAUDE.md` first — it has the layer map and the critical rules. The
non-negotiables:

- **Resolve components through the theme** — `PhlexForms::Theme` maps a role
  (`:input`, `:select`, `:control`, …) to a component class, so the same form
  renders daisy or Plain. A new leaf needs BOTH a daisy component and a
  `Forms::Plain::*` one (accepts-and-ignores variants, `aria-invalid` /
  `data-field-error` hooks, zero styling classes).
- **Guard every model touch** — inference (`PhlexForms::Inference`) and field
  metadata (`Forms::Field`) sit behind `respond_to?` + `rescue StandardError`,
  so POROs / Structs / untyped ActiveModel degrade to the attribute-name map.
  Never require ActiveRecord.
- **daisyui and phlex-reactive are SOFT dependencies** — `require`-rescue-
  `LoadError` + Zeitwerk `ignore`. The gem must boot and render (Plain theme)
  without either; the `live` macro raises a clear `FeatureUnavailable` when
  phlex-reactive is absent.
- **Literal class strings only** — `"input input-primary"`, never
  `"input-#{x}"`; interpolated names get tree-shaken by the host's Tailwind scan.
- **Never `raw`/`html_safe` user or model data** — field names, choices, and
  values are user-influenced; let Phlex escape.
- **TDD**: write the failing spec first — `spec/phlex_forms/` for pure logic
  (inference precedence, config, theme), `spec/forms/` for rendered output via
  the `render_form` kit helper. Assert on semantics (`name=`, selected option,
  error text), not HTML snapshots. Model doubles come from `build_model`
  (ActiveModel, `spec/support/model_helpers.rb`) — no database.

### B. Write a docs page for phlex-forms' own docs site (under `docs/`)

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

## Verify before you finish (every change)

```bash
bundle exec rspec              # the suite (unit + integration render specs)
bundle exec rubocop lib spec   # lint — no offenses (rubocop -A lib spec to fix)
bundle exec rake               # both, together
```

Ruby floor is **3.4** (the CI matrix is 3.4 + 4.0). The `docs/` app has its own
bundle (Ruby 4.0.5). Never `gem push` by hand — release via `rake release[X.Y.Z]`
(it stages only the version file; `Gemfile.lock` is gitignored, correct for a gem).
