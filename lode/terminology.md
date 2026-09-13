# Terminology

- **builder** — the object yielded by `Form(model:) { |f| … }`, and `self`
  inside a `Forms::Base#fields`. The API is the `PhlexForms::Builder` mixin,
  included by `Forms::Form` and `Forms::FieldsForBuilder`.
- **the `field` verb** — `Builder#field(name, *modifiers, **options)`: the
  primary API. Renders a **control** wrapping label + input + error/hint.
- **escape hatch** — the ten PascalCase builder methods (`Input`, `Select`,
  `Textarea`, `Checkbox`, `Radio`, `Toggle`, `FileInput`, `Hidden`, `Label`,
  `Control`, `builder.rb:137-191`), plus `hidden_field` (a Rails-`FormBuilder`
  alias of `Hidden`) and `Form#submit`. Same model binding, no control wrapper,
  no inference beyond the attribute-name map.
- **leaf component** — a `Forms::*` Phlex component that renders one element
  (`Forms::Input`, `Forms::Select`, …). Reached through a theme role, never by
  name.
- **role** — a theme key (`:input`, `:select`, `:control`, `:hidden`, …).
  `PhlexForms::Theme#[]` maps a role to a leaf class and raises `KeyError`
  listing the known roles for an unknown one.
- **Plain twin** — the `Forms::Plain::*` subclass of a daisy leaf that
  overrides only rendering (a `view_template`, or the styling seams), accepts
  positional variants and ignores them, ships zero styling classes, and signals
  invalidity with `aria-invalid` instead of a colour class.
- **binding contract** — the leaf initializer keywords a theme swap must
  preserve: `*modifiers, name:, id:, value:, error:, disabled:, required:`.
  `:hidden` is the deliberate exception — `name:`/`id:`/`value:` only.
- **delegation** — a daisy leaf hands its markup to the `daisyui` gem
  (`render DaisyUI::Input.new(*daisy_modifiers, **binding_attributes)`) instead
  of writing daisyUI classes itself; the helpers are in
  `PhlexForms::DelegatedField`.
- **modifier** — a positional Symbol on a component call (`:primary`, `:lg`).
  Most name a daisyUI variant; the 16 in `Builder::INPUT_TYPE_MODIFIERS` name an
  input type instead and are stripped before the leaf sees them.
- **field variants** — modifiers prepended to every `field`'s inner input;
  stacked global (`PhlexForms.config.field_variants`) → form
  (`field_variants:` / `form_options`) → call site, last wins.
- **inference** — `PhlexForms::Inference.resolve`, returning a `Result` Data
  object (`as`, `name`, `label`, `choices`, `attributes`, `multiple`,
  `required`). Gated by `PhlexForms.config.infer_from_model`.
- **name rewrite** — inference resolving `:country` to the foreign key
  `:country_id` for a `belongs_to`; the field renders under the new name while
  errors still read from the association name (`error_name:`).
- **client-side validation** (`validate: true`) — `Forms::Validations::
  Introspector` translating the model's own validators into `data-validations--*`
  attributes that the eight bundled Stimulus field controllers re-check in the
  browser. Server validation stays authoritative.
- **live validation** (`live model: …`) — the whole form as one phlex-reactive
  component; blur and a debounced form-wide input POST to a `:validate` action
  that assigns a whitelist, runs the real validators, and morphs the reply back.
  Nothing is persisted.
- **touched** — the reactive state list of field names the user has left; an
  untouched field is rendered with no errors so nothing flashes early.
- **rootless tag field** — the tag widget rendered without its own reactive
  root, so the enclosing live `<form>` owns its hidden field. Lifted onto the
  form root by `live_tags`.
- **the docs site** — the docs-kit Rails app under `docs/`, with its own
  bundle, Ruby version, RuboCop config and lockfile; it path-depends on the gem.
- **lode** — this directory: the repo's durable memory. `lode/review/` holds
  accepted review findings as rules; `/lode:gate` enforces them before a push.
