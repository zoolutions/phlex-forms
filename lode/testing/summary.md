# Testing: layers, helpers, and what is and is not covered

RSpec, 18 spec files, **202 examples** (`bundle exec rspec --dry-run`; a line-based `grep` for `it` says 198 because `spec/forms/components_spec.rb` builds five examples from one `each` loop) (`grep -rhE '^\s*it ["(]' spec
--include='*_spec.rb' | wc -l`). `.rspec` loads `spec_helper` for every file and
prints documentation format; the suite runs in random order with a seeded
`srand`.

## The three layers

| Layer | Path | Boots | For |
|---|---|---|---|
| Unit | `spec/phlex_forms/**` | nothing | `Inference` precedence, `ClassMerge` families |
| Integration | `spec/forms/**` | a Phlex kit context, no Rails request | that a rendered form emits the expected markup for a bound model |
| Cops | `spec/rubocop/cops_spec.rb` | RuboCop against source snippets | the two cops flag and autocorrect |

## Helpers (`spec/support/`, all four included globally)

- `ModelHelpers#build_model(name, validations: -> { … }, **attributes)` — an
  anonymous `ActiveModel::Model` + `ActiveModel::Attributes` class with a real
  `name` singleton (ActiveModel::Naming needs one) and the given attributes.
  Validations are applied with `class_exec`, not `class_eval`, so an arity-0
  lambda is not rejected for the implicit class argument. No database.
- `PhlexHelpers#render_form(model, **form_args) { |f| … }` — renders a real
  `Forms::Form` through a `Phlex::HTML` context that `include Forms`, exactly as
  a host app would. `#kit(&)` is the lower-level version for bare kit helpers.
- `ComponentHelpers#render_component(component, &)` — named so it does not
  shadow Phlex's own instance-level `render` inside component contexts.
- `HTMLHelpers#html(string)` — whitespace normalisation so a spec can compare
  against a readable heredoc.

## Global setup (`spec/spec_helper.rb`, 49 lines)

- Loads `i18n`, `active_model`, `phlex-forms`, `super_diff/rspec`.
- Pushes the gem's own `config/locales/*.yml` onto `I18n.load_path` and sets
  `available_locales` to `en sv de` — the engine does this in a host app, so
  without it `Forms::Submit`'s `I18n.t("cmd.create_model")` would not resolve.
- When `Phlex::Reactive` is defined, installs a `MessageVerifier` (token signing
  happens on every live render) and calls `Forms::Live.register_param_type!`.
- `config.after { PhlexForms.reset_configuration! }` — the one global reset. A
  spec that sets a theme, an icon renderer or `infer_from_model` does not have
  to clean up; a spec that mutates anything **else** global does.

## Conventions the suite follows

- Assert on semantics — `name="user[email]"`, the selected option, the error
  text, the error variant class — never a full-HTML snapshot.
- Live specs are guarded by `if defined?(Phlex::Reactive)` and stub the reply,
  since no endpoint is booted. The one behaviour a spec cannot drive —
  `verify_authorized` — is asserted at class level
  (`skip_verify_authorized?(:validate)`).
- Both themes get exercised where a Plain twin exists.

## Coverage, honestly

Well covered: `Inference` precedence (17 examples), `ClassMerge` (13),
`Forms::Form` (28) and the leaf components (28 in `components_spec.rb`),
`checkbox_group` (26), the tag field across three files (14 + 5 + 4) and its
Plain twin (4), `Introspector` (11), `Live` (11), `rich_textarea` (8), `Theme`
(8), `Base` (5), `file_input` (5), `layout` (4), the cops (6).

Thin or absent:

- **`PhlexForms::Configuration` has no spec file of its own.** Its knobs
  (`theme`, `infer_from_model`, `field_variants`, `icon_renderer`) are exercised
  only indirectly, through the form and theme specs.
- **The Stimulus controllers have no JS tests** — there is no JS test runner in
  the repo. Everything under `app/javascript/` is verified only by reading.
- `spec/forms/time_zone_select_spec.rb` has a single example.
- No spec renders the gem inside a real Rails app, so `PhlexForms::Engine`'s
  four initializers are uncovered.

## CI

`.github/workflows/main.yml`: `Lint` runs `bundle exec rubocop lib spec` on
Ruby 4.0; `Specs (Ruby 3.4)` and `Specs (Ruby 4.0)` run `bundle exec rspec`,
with `fail-fast: false` so both Ruby cells report. Nothing in the suite touches
the network or a database, so two checkouts can run it concurrently.

The local pre-commit gate is `bundle exec rspec && bundle exec rubocop lib spec`.
`bundle exec rake` (the default task, `spec` then `rubocop`) cannot be used:
`RuboCop::RakeTask` passes no paths, so RuboCop walks into `docs/`, reads
`docs/.rubocop.yml` and aborts with `cannot load such file --
docs_kit/rubocop` — the docs app's RuboCop plugin lives in its own bundle.

## Related

- `../workflow.md` — the commands, and the shapes every change is checked
  against
- `../packaging/summary.md` — the release workflow's own test job
