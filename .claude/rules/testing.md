# Testing Rules

## TDD Workflow

Follow RED → GREEN → REFACTOR:

1. **RED**: Write a failing test first
2. **GREEN**: Write minimal code to pass
3. **REFACTOR**: Improve code while keeping tests green

## The test layers

phlex-forms is a Phlex form-builder gem. Tests split by namespace — the
`PhlexForms::` internals are unit-tested in isolation; the `Forms::` components
are exercised end-to-end by rendering a real form. Cheapest first:

| Layer | Path | Boots | Use for |
|-------|------|-------|---------|
| Unit | `spec/phlex_forms/**` | nothing | `PhlexForms::Inference` (precedence), `Configuration` (knobs), `Theme` |
| Integration | `spec/forms/**` | a Phlex kit context (no Rails request) | that a rendered form emits the expected markup for a bound model |
| Cops | `spec/rubocop/cops_spec.rb` | RuboCop against source snippets | the `RawForm` / `LegacyFormMethod` cops flag and autocorrect |

A `spec/phlex_forms/**` unit spec calls the module directly — e.g.
`PhlexForms::Inference.resolve(model:, name:)` and asserts on the resolved
`as`/`name`/`choices`/`attributes`. A `spec/forms/**` integration spec renders a
whole form and asserts on the produced markup. Prefer asserting on
**behavior/semantics** (the input type inferred, `maxlength` present, an error
surfaced) over brittle full-HTML snapshots.

### Model doubles — `build_model` (ActiveModel, no DB)

`ModelHelpers#build_model` (in `spec/support/`) builds an anonymous
`ActiveModel::Model` + `ActiveModel::Attributes` class so specs exercise binding,
`human_attribute_name`, error hydration, and validation-derived inference
(`required?`, `maxlength`) without a database:

```ruby
model = build_model(:user, email: "a@b.c",
  validations: -> { validates :email, presence: true, length: { maximum: 30 } })
```

### Rendering a form — `render_form`

`PhlexHelpers#render_form(model, **form_args) { |f| ... }` renders a
`Forms::Form` for `model` through a kit context, yielding the builder exactly as
`Form(model:) { |f| ... }` does in a host app that `include Forms`:

```ruby
output = render_form(user) { |f| f.field(:email, hint: "No spam") }
expect(output).to include('type="email"')
```

## Coverage Expectations

- Aim for **80%+** across the gem.
- Target **100%** for the public API surface — `PhlexForms::Inference`,
  `PhlexForms::Configuration`, and `PhlexForms::Theme` — since host apps depend on
  their behavior directly.

## RSpec Conventions

```ruby
subject(:result) { PhlexForms::Inference.resolve(model:, name: :price) }

it "infers :number from a decimal column and derives step" do
  expect(result.as).to eq(:number)
  expect(result.attributes).to include(step: instance_of(Float))
end

context "when the model is a plain object (no validators_on)" do
  it "falls through to the attribute-name map" do
    # respond_to?-guarded probes degrade for POROs
  end
end
```

Render integration specs through `render_form` (or the lower-level `kit`
helper); unit specs call the `PhlexForms::` module directly.

## What to cover

- **Inference precedence** — the first-hit-wins order (explicit `as:` > positional
  modifier > `choices:` > model structure > column type > name map > `:text`).
- **PORO fallthrough** — a model without `validators_on`/`type_for_attribute`
  degrades to the attribute-name map (no `NoMethodError`).
- **Configuration knobs** — `infer_from_model`, `field_variants`, `theme`,
  `icon_renderer` each reflect their setting.
- **Theme parity** — a field renders under BOTH `:daisy` and `:plain`; the plain
  theme emits bare semantic HTML with aria/data hooks only.
- **Validation-derived attributes** — `maxlength`/`min`/`max`/`required` come from
  the model's validators and lose to caller-passed options.

## Test Checklist

- [ ] Tests written BEFORE implementation; RED verified
- [ ] `bundle exec rspec` green
- [ ] Component output asserted on semantics, not brittle full-HTML snapshots
- [ ] Inference precedence + PORO fallthrough covered
- [ ] Rendered under both themes where a Plain twin exists
- [ ] `bundle exec rubocop lib spec` passes
