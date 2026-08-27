# phlex-forms

A model-bound form builder for [Phlex](https://www.phlex.fun) — forms as
first-class Phlex classes, types inferred from your model, DaisyUI styling by
default (and a plain-HTML theme when you want none), and optional
**server-truth live validation** over
[phlex-reactive](https://github.com/zoolutions/phlex-reactive).

```ruby
class UserForm < Forms::Base
  live model: User                 # real validators, live, focus preserved

  def fields                       # self IS the form — no f. prefix
    field :email                   # name → type=email, required inferred
    field :role                    # AR enum → select, humanized
    field :country                 # belongs_to → select over the association
    field :notify                  # boolean column → toggle
    field :bio                     # text column → textarea
    row do
      field :first_name
      field :last_name
    end
    submit :primary
  end
end

render UserForm.new(model: @user)
```

For one-offs, the inline builder does the same with a yielded form:

```ruby
Form(model: @user) do |f|
  f.field :email, hint: t("users.email_hint")
  f.field :bio
  f.submit :primary
end
```

## Installation

```ruby
# Gemfile
gem "phlex-forms"
gem "daisyui"        # optional — the daisy theme; omit for plain semantic HTML
gem "phlex-reactive" # optional — the `live` server-truth validation
```

phlex-forms exposes its components under the `Forms::` namespace as a
[Phlex::Kit](https://www.phlex.fun/kits.html). Include it wherever you render
components (typically your `ApplicationComponent` / base view):

```ruby
class ApplicationComponent < Phlex::HTML
  include Forms
end
```

## Form classes (`Forms::Base`)

Subclass `Forms::Base`, declare the fields in `#fields`, render. The whole
builder surface (`field`, `row`, `group`, `Input`, `submit`, `fields_for`, …)
is available as bare calls — the form is an object you can reuse, subclass,
and test in isolation.

```ruby
class ApplicationForm < Forms::Base
  form_options :spaced, field_variants: [:primary]   # inherited defaults
end

class UserForm < ApplicationForm
  form_options url: "/signup"                        # merged over the parent's

  def fields
    field :email
    submit :primary
  end
end

render UserForm.new(model: @user)                    # instance args win
render UserForm.new(model: @user) { |f| f.Hidden(:token) }  # appends after fields
```

## The `field` API

`f.field(name, *modifiers, **options)` is the primary verb: one call renders a
control wrapping the label, the input, and an error (or hint).

| Option | Effect |
| --- | --- |
| `label:` | Label text. Defaults to the model's humanized attribute name. `label: false` omits it. |
| `hint:` | Help text shown when there is no error. |
| `as:` | Override the control: `:select`, `:textarea`, `:toggle`, `:checkbox`, `:file`, `:radio`, `:hidden`, `:rich_textarea`, `:tags` (see [Tag fields](#tag-fields)), or any text-like type. |
| `required:` | Force the required flag. Otherwise inferred from the model's presence validators. |
| `choices:` | Choices for a select (implies `as: :select`). |
| positional modifiers | daisyui variants — `:primary`, `:lg`, `:ghost`, … — stacked onto the input. |

### Model-driven inference

`field :x` interrogates the bound model, so `as:` is an override, not a
requirement. Precedence (first hit wins):

1. Explicit `as:`
2. A positional type modifier (`field :price, :number`)
3. `choices:` → select
4. Model structure — `has_rich_text` → rich textarea; ActiveStorage attachment
   → file input (`multiple` for `has_many_attached`); ActiveRecord enum →
   select over humanized keys; non-polymorphic `belongs_to` (as `:country` or
   `:country_id`) → select over the association (`name="user[country_id]"`,
   label and required flag from the association, errors surface from
   `:country`)
5. Non-string column type — boolean → toggle, text → textarea,
   date/datetime/time → matching inputs, integer/decimal/float → number with
   a sensible `step`
6. The attribute-name map (`email` → `type=email`, `password` →
   `type=password`, `phone` → `type=tel`, …)
7. `type=text`

Length and numericality validators also emit `maxlength`/`min`/`max`
(conditional validators are skipped; caller options always win). Everything is
duck-typed behind `respond_to?` guards — plain objects, Structs, and form
objects fall through to the name map, exactly as before. Opt out entirely
with:

```ruby
PhlexForms.configure { |c| c.infer_from_model = false }
```

Association selects load `klass.all` per render — pass `choices:` to scope,
order, or cache.

### Variants

daisyui variants stack positionally, per field or as defaults:

```ruby
f.field :email, :primary, :sm                        # this field
Form(model: @user, field_variants: [:primary])       # every field in this form
form_options field_variants: [:primary]              # every field in this class
PhlexForms.configure { |c| c.field_variants = [:sm] }  # everywhere
```

Defaults stack first, call-site modifiers last — the most local wins.

### Layout

```ruby
row { field :first_name; field :last_name }   # responsive grid, columns: 2|3|4
group(legend: "Address") do                   # <fieldset> + legend
  field :street
  field :city
end
```

Both work on inline forms (`f.row { … }`) and inside `fields_for` builders.

### Tag fields

`as: :tags` renders a polished tag/chip input — label + error/hint chrome and
daisyUI styling on top of
[phlex-reactive](https://github.com/zoolutions/phlex-reactive)'s client-only tag
primitives (form state, no server round trips). **Requires phlex-reactive** (the `:tags` role is
registered only when it's loaded).

```ruby
f.field :tags, as: :tags, suggestions: %w[Ruby Rails Hotwire Postgres]

# Hash form: the value is a "haystack" of synonyms the type-ahead filter matches
f.field :tags, as: :tags, suggestions: { "Postgres" => "postgres database db sql" }
```

The widget submits **one comma-joined param** (`user[tags] = "Ruby,Rails"`) — the
primitive's wire contract. The visible type-ahead input carries **no `name`**, so
it never posts a stray param; only a hidden field does.

Have the model split the comma-joined string back into an array:

```ruby
class Post < ApplicationRecord
  attribute :tags, default: []            # a text[] / JSONB column, say

  # accept the widget's "Ruby,Rails" and a normal Array alike
  def tags=(value)
    super(value.is_a?(String) ? value.split(",").map(&:strip).reject(&:empty?) : value)
  end
end
```

Notes:

- **Custom styling** — the leaf reads daisyUI classes from overridable seams
  (`root_classes`, `chip_classes`, `menu_classes`, …). The plain theme's twin
  (`Forms::Plain::TagField`) keeps the full client wire contract but ships zero
  styling classes; the invalid state rides `aria-invalid` on the query input.
- **Inside a `live` form**, declare `live_tags` so the outer form validates the
  tags too. A standalone tag widget is a *nested* reactive root, so the live
  root would skip its hidden field — `live_tags` lifts the widget's wire
  attributes onto the `<form>` root and renders the widget rootless, so the form
  owns the hidden field and `:validate` sees the value:

  ```ruby
  class PostForm < Forms::Base
    live model: Post
    live_tags :tags, suggestions: %w[Ruby Rails Hotwire]  # lift onto the form root

    def fields
      field :title
      field :tags, as: :tags        # renders rootless; the form validates it
      submit :primary
    end
  end
  ```

  phlex-reactive's tag controller reads **one** tag field per root, so a live
  form lifts **at most one** — a second `live_tags` raises. A second tag input
  must stay a standalone (non-live) `field :other, as: :tags`.

## Escape hatches & custom widgets

The lower-level component methods are always available with stable signatures:

```ruby
f.Input(:name, :primary, :lg)     # bare input, variants stacked
f.Select(:role, choices: roles)   # native <select>
f.Textarea(:bio, :ghost)
f.Checkbox(:terms) ; f.Toggle(:notify) ; f.FileInput(:avatar)
f.Label(:email) ; f.Hidden(:token) ; f.submit("Save", :primary)
```

Migrating from Rails' `FormBuilder`? `f.hidden_field(:token, value: x)` is a
snake_case alias for `f.Hidden` — same model-bound path, and an explicit
`value:` wins over the model's current value — so those call sites port over
verbatim.

For a bespoke widget (date picker, tag field, remote select), wrap it in
`f.Control` and bind through the public helpers — this is the supported path,
not a fork reason:

```ruby
f.Control(:starts_at, label: "Starts") do
  render MyDatePicker.new(
    name: f.field_name(:starts_at),
    id: f.field_id(:starts_at),
    value: f.field_value(:starts_at)
  )
end
```

Icons inside a field (daisyui v5 `<label class="input">` pattern):

```ruby
f.field(:search).wrapped_input(:primary) do
  LucideIcon("search", class: "opacity-50")
end
```

## Themes — using phlex-forms without daisyui

Every component resolves through a theme (a role → component-class map). With
the daisyui gem loaded, the daisy theme is the default. Without it — or on
demand — the **Plain theme** renders bare semantic HTML: the same binding
(names, ids, values, required, errors), variants accepted and ignored, no
styling classes, and stable hooks (`aria-invalid`, `role="alert"`,
`data-field-error`, `data-field-hint`, `data-form-row`) for your own CSS.

```ruby
render UserForm.new(model: @user, theme: :plain)     # per render
form_options theme: :plain                           # per class
PhlexForms.configure { |c| c.theme = :plain }        # global

# override single roles:
PhlexForms.configure do |c|
  c.theme = PhlexForms::Theme.resolve(:plain).with(input: MyInput)
end
```

The same `UserForm` class renders under either theme — write the form once,
style it per project. (Plain degradations: `searchable:` selects fall back to
the native select; `rich_textarea` falls back to a plain textarea.)

## Live validation (server-truth, via phlex-reactive)

The `live` macro turns the whole form into one reactive component. Blurring a
field (or typing, debounced) POSTs **all** form fields to a single signed
`:validate` action; the server assigns a whitelisted slice to the model, runs
the **real** ActiveModel validators, and morphs the errors back in — the
focused input and caret survive.

```ruby
class UserForm < Forms::Base
  live model: User, debounce: 300

  def fields
    field :email                  # uniqueness validates against the real DB
    field :password
    field :password_confirmation  # cross-field confirmation just works
    submit :primary
  end
end
```

What you get over any client-side mirror:

- **One source of truth** — uniqueness, `:if`/`:unless`, `:on` contexts,
  cross-field and custom validators all run, because it *is* your model.
- **i18n is plain Rails i18n** — no duplicated message catalogs.
- **No premature errors** — a field's error first appears on blur (`touched`
  tracking rides the signed token; zero client-side bookkeeping), while fixing
  a field live-updates errors of fields you already touched.
- **Progressive enhancement** — nothing is ever persisted by `:validate`;
  native submit and your controller stay authoritative. A failed-submit 422
  re-render shows all errors as usual.

Constraints: `live` needs a `Forms::Base` subclass (the endpoint rebuilds the
form from its class — an inline block cannot be serialized; `Form(live: true)`
raises and says so). Collection controls (`collection_check_boxes`,
multi-selects) are excluded from live assignment in v1. Use
`live_permit`/`live_deny` to adjust the assignable attributes; setters run on
an in-memory model only.

### Client-side fallback (`validate: true`)

Without phlex-reactive, the bundled Stimulus framework mirrors your validators
client-side:

```ruby
Form(model: @partner, validate: true) do |f|
  f.field :title                              # every validator on :title
  f.field :slug, validate: false              # opt this field out
  f.field :note, validate: { length: { maximum: 30 } }  # explicit rules
end
```

Supported: presence, length (with a live counter), format, numericality,
inclusion, exclusion, confirmation, acceptance. Validators with
`:if`/`:unless`/`:on` are skipped; uniqueness can't be checked client-side —
the server stays authoritative. Register the controllers:

```js
// app/javascript/controllers/index.js
import { lazyLoadControllersFrom } from "@hotwired/stimulus-loading"
lazyLoadControllersFrom("phlex_forms/controllers", application)
```

The emitted identifiers are `validations--presence`, `validations--length`, … (and
the form-level `validations--form` coordinator), which `lazyLoadControllersFrom`
resolves to `phlex_forms/controllers/validations/*_controller` — the path the gem
ships them at.

Messages ship for `en` / `fr` / `af`; override via `window.PhlexForms.messages`.

## Nested attributes, collections & escape valves

```ruby
f.fields_for(:line_items) do |item|          # single assoc or has_many
  item.field :description
end

f.fields_for(:settings, nested_attributes: false) do |s|
  s.field :locale                            # user[settings][locale] — JSONB/hash columns
end

f.collection_check_boxes(:role_ids, Role.all, :id, :name) do |b|
  render b.check_box                          # per-item control, full custom layout
  render b.label
end

# The batched "tag/facet picker" shape: one array-valued field name, checked
# state derived from the model (record.tag_ids), sensible defaults, no block.
f.checkbox_group(:tag_ids, Tag.all, value: :id, label: :name)
f.checkbox_group(:tag_ids, Tag.all, value: :id,
  label: ->(t) { t.name.presence || t.slug }, # Symbol method or Proc
  variant: :pill,                             # :stack (default) | :inline | :pill
  size: :sm,                                  # daisyUI checkbox size
  aria: { label: "Tags" })                    # names the group for screen readers
# ...or through field inference. Here `label:`/`hint:` are the field's VISIBLE
# heading + description (rendered by the Control, which also names the group);
# `item_label:` gives the per-item text, so you get a heading AND custom item
# labels at once:
f.field :tag_ids, as: :checkbox_group, collection: Tag.all, value: :id,
  label: "Tags", hint: "Pick any",
  item_label: ->(t) { t.name.presence || t.slug }, variant: :pill

f.collection_select(:country_id, Country.all, :id, :name, prompt: "Select…")
```

`checkbox_group` submits an array param (`user[tag_ids][]`) with a leading
empty-array hidden field, so deselecting everything still submits. The checked
set comes from the model's current value matched by each item's resolved
`value:` — re-rendering an edit form pre-checks the right boxes. The `:pill`
variant styles the active chip with Tailwind's `has-[:checked]:` (no JS).

**Two labels, no collision.** Through `f.field`, `label:` is the field's visible
group heading (the Control renders it); the per-item text comes from `item_label:`
(a Symbol method or Proc). On the bare `f.checkbox_group` verb there is no Control
heading, so `label:` *is* the per-item accessor (and `item_label:` is accepted as
an alias). Either way `value:` is the submitted value; `item_label:` wins over
`label:` for the item text when both are present.

A `role="group"` needs an **accessible name** for assistive tech. The verb has
no bespoke naming option — HTML/ARIA attributes pass straight through to the
group, so name it with plain `aria:` (`aria: { label: "Tags" }` for a literal
name, or `aria: { labelledby: "some_id" }` to point at an existing element).
Through `f.field`, the Control's own visible `label:` / `hint:` name the group
automatically (the field wires `aria-labelledby` / `aria-describedby` at them).
Without a name the group renders as before — naming is the caller's call, the
same posture as Rails' derived form markup.

Field ids derive from scope + name (+ value for group items), exactly like
Rails' `form_with`; the gem does not guarantee page-wide id uniqueness across
multiple forms for the same model — scope one form (`Form(model:, scope: …)`) to
disambiguate, as you would in Rails.

`Form(model: @item, scope: false)` emits **bare** field names
(`name="quantity"`) — the shape phlex-reactive row editors and
`<template>`-cloned rows need. External widgets bind through the public
`f.field_name` / `f.field_id` / `f.field_value` helpers.

## Icons

Icons default to a bundled inline SVG so the gem is self-contained. To use
[`glyphs`](https://rubygems.org/gems/glyphs):

```ruby
PhlexForms.configure do |c|
  c.icon_renderer = PhlexForms::Configuration.glyphs_renderer
end
```

## RuboCop cops

Two cops nudge call sites toward the phlex-forms API. Enable them in your
`.rubocop.yml`:

```yaml
require:
  - phlex_forms/rubocop
inherit_gem:
  phlex-forms: config/rubocop.yml
```

- `PhlexForms/RawForm` — use `Form()` over `form_with` / raw `form()` (autocorrects).
- `PhlexForms/LegacyFormMethod` — use `form.field(...)` / the PascalCase methods
  over Rails-style `text_field` / `select` / etc.

## Dependencies

- Hard: `phlex` (~> 2.0), `activesupport`, `zeitwerk`, `glyphs`.
- Soft: `daisyui` (the daisy theme — without it the Plain theme is the
  default), `phlex-reactive` (the `live` macro).
- JS peers: `@hotwired/stimulus` (client validation fallback), `choices.js`
  (only for `searchable: true` selects).

## Companion

Form-level error summaries (`FormErrors`) live in your app's UI kit, not here —
pair them with `Form()` as you like.

## License

MIT © Mikael Henriksson
