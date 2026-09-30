# Coding Style Rules

## File Organization

**MANY SMALL FILES > FEW LARGE FILES**

- High cohesion, low coupling
- 200-400 lines typical
- 800 lines maximum per file
- Extract complex logic to dedicated classes
- Organize by concern (`PhlexForms::` internals: config/inference/theme/class-merge; `Forms::` components: the daisy leaves and their `Forms::Plain::*` twins)

## Ruby Style

Lint with **RuboCop** (`bundle exec rubocop lib spec`). RuboCop owns formatting —
don't hand-fight it; run `rubocop -A` and review.

### Classes & Methods

```ruby
# Good: small, focused methods
def resolve(model:, name:, as: nil, modifiers: [], choices: nil)
  result = base_result(model:, name:, as:, modifiers:, choices:)
  return result unless infer_from_model?

  merge_validator_attributes(result, model)
end

# Bad: one giant method doing modifier scan, column lookup, validator merge, and fallback
```

### Guard every model touch with `respond_to?` — degrade for POROs

Introspection must never assume ActiveRecord. Sit each model touch behind a
`respond_to?` check and rescue `StandardError` back to a safe default, so a
Struct/PORO/Ransack search falls through the same as a bare column.

```ruby
# Good: the required? / Inference posture — guard, then rescue to a safe default
def required?
  return false unless @model.respond_to?(:class) && @model.class.respond_to?(:validators_on)

  @model.class.validators_on(@name).any? { |v| presence?(v) }
rescue StandardError
  false
end

# Bad: assume the model has validators_on / type_for_attribute (NoMethodError on a PORO)
def required? = @model.class.validators_on(@name).any? { presence? }
```

`PhlexForms::Inference` follows the same rule: every structural probe
(`reflect_on_association`, `type_for_attribute`, `defined_enums`, `validators_on`)
is `respond_to?`-gated and rescued, so unknown shapes fall back to the
attribute-name map.

### Literal Tailwind/daisy class strings — never interpolate

Class strings must be scanner-visible so a CSS build can see every emitted class.
Write them literally; do not build them with `#{...}`.

```ruby
# Good: literal, greppable class strings
input(class: "input input-bordered w-full")

# Bad: interpolated — invisible to a scanner, and an injection risk if the value is dynamic
input(class: "input input-#{size} #{state}")
```

Conflicting classes (daisy sizes/colors, Tailwind utilities like `w-*`, `mt-*`,
`text-sm`) are resolved by daisyui's merger (later conflicting classes win) — not
by string surgery and not by pulling in `tailwind_merge`. A `class:` handed to a
`DaisyUI::*` component is merged by `DaisyUI::Base` (put the default first); a
raw element (`div`/`p`/`form`) merges via
`DaisyUI::ClassMerge.merge(default, @options[:class])`.

### Soft dependency: phlex-reactive (require-rescue-LoadError + Zeitwerk ignore)

`daisyui ~> 2.0` is a hard dependency (required unconditionally). `phlex-reactive`
is optional. Load it with a rescued `require`, and ignore its dependent files in
the Zeitwerk loader so the gem boots without it:

```ruby
# Good: soft dep — the `live` macro raises FeatureUnavailable when it's absent
begin
  require "phlex/reactive"
rescue LoadError
  # no phlex-reactive -> live/tag_field files are ignored below
end

# The live-validation layer includes Phlex::Reactive::Component at class level,
# so it can only load when phlex-reactive is present.
unless defined?(Phlex::Reactive)
  loader.ignore("#{__dir__}/forms/live.rb")
  loader.ignore("#{__dir__}/forms/live")
end

# Bad: referencing Phlex::Reactive unguarded (NameError in a non-reactive host)
```

### Delegate daisy leaves to the daisyui gem via `DelegatedField`

A daisy leaf component should NOT re-emit daisyui markup by hand. Set
`@modifiers/@error/@required/@attributes` and delegate through
`PhlexForms::DelegatedField` (`#daisy_modifiers`, `#binding_attributes`) so
variant handling and the error class live in one place.

```ruby
# Good: hand the assembled args to the daisyui gem component
render DaisyUI::Input.new(*daisy_modifiers, **binding_attributes(value: @value))

# Bad: reconstruct `input input-bordered input-error ...` inline in the component
```

## Code Quality Checklist

Before marking work complete:
- [ ] Code is readable and well-named
- [ ] Methods are small (<30 lines ideal, <50 max)
- [ ] Files are focused (<800 lines)
- [ ] No deep nesting (>4 levels)
- [ ] Every model touch is `respond_to?`-guarded and rescues to a safe default (POROs degrade)
- [ ] Class strings are literal and scanner-visible — no interpolation
- [ ] phlex-reactive stays a soft dep (require-rescue-LoadError + Zeitwerk ignore)
- [ ] Default + caller classes merge via daisyui (`DaisyUI::Base` or `DaisyUI::ClassMerge.merge` on raw elements)
- [ ] Daisy leaves delegate to the daisyui gem via `DelegatedField`; a Plain twin exists
- [ ] `bundle exec rubocop lib spec` passes
