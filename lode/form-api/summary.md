# Form API: the builder, the form, the field

## The three hosts of one API

`PhlexForms::Builder` (`lib/phlex_forms/builder.rb`, 235 lines) is the whole
caller-facing surface. It is a mixin, and its hosts supply five things:
`render`, `model`, `scope`, `errors`, and `field_object(name, error_name:)`.

| Host | File | What it adds |
|---|---|---|
| `Forms::Form` | `lib/forms/form.rb` (277) | the `<form>` element, scope/url/method derivation, CSRF + `_method` + `enctype`, `fields_for`, the Rails-parity collection helpers |
| `Forms::Base` | `lib/forms/base.rb` (100) | declarative subclasses — `form_options`, `#fields`, the `live` macro |
| `Forms::FieldsForBuilder` | `lib/forms/fields_for_builder.rb` (71) | a nested scope; renders and themes through `@parent_form` |

`Forms::Base < Forms::Form`, so a declarative form is a form. `FieldsForBuilder`
is not — it only includes the mixin and delegates `render`, `theme` and
`default_field_variants` to the parent (`fields_for_builder.rb:21-36`).

`Form` also carries three Rails-`FormBuilder` compatibility aliases so call
sites that introspect the bound record keep working: `object` → `model`,
`object_name` → `scope` (`form.rb:25-26`) and `[]` → `field_object`
(`form.rb:75`), which is what makes `f[:email].hidden` read.

## `field` — what one call does

`Builder#field` (`builder.rb:67-94`), in order:

1. prepends `default_field_variants` to the positional modifiers;
2. asks `PhlexForms::Inference.resolve` for the control kind, the (possibly
   rewritten) attribute name, a label, choices, attributes, `multiple` and
   `required` — see `../inference/summary.md`;
3. builds a `Forms::Field` for the **inferred** name while passing the
   **original** name as `error_name:`, so a `belongs_to` rendered as
   `country_id` still shows the error Rails put on `country`;
4. resolves `required` — an explicit `required:` wins, else the field's own
   presence validators or the inferred association requirement;
5. resolves the label — `label: false` omits it, else `label:`, else the
   inferred association label, else `Field#field_label`;
6. merges attributes **inference first, caller last** (`options =
   inferred.attributes.merge(options)`), then layers validator-derived
   attributes underneath via `Field#apply_validations`;
7. for `multiple` (a `has_many_attached`), sets `multiple: true` and an
   array `name` unless the caller already passed them;
8. materializes `choices` — inference hands back a lambda for association
   choices, called only when the caller passed none (`materialize_choices`,
   `builder.rb:226-228`);
9. computes the checkbox-group ARIA pair (below);
10. renders `fo.control(…)` and yields the inner input to it.

### `render_field_input` — the `as:` dispatch

`builder.rb:196-216` switches on `as || resolve_input_type(name, modifiers)`.
Nine kinds have their own branch: `:select`, `:textarea`, `:toggle`,
`:checkbox`, `:checkbox_group`, `:file`, `:hidden`, `:rich_textarea`, `:tags`.
**Everything else is treated as an input type** and rendered through the
`:input` role with `type:` set to it (`:datetime` is rewritten to
`:"datetime-local"`). So `as: :radio` does not reach the `:radio` role — it
renders `<input type="radio">` through the input leaf.

Two kinds deliberately drop `required:` before rendering: `:checkbox_group`
(one array name shared by many boxes, so the browser cannot satisfy it) and
`:tags` (the value lives in a hidden field). Both are commented at the branch.

### Checkbox-group ARIA (`group_aria`, `builder.rb:101-115`)

A checkbox group renders `div[role="group"]`, which a plain `<label for>`
cannot name. For `as: :checkbox_group` **only**, the builder stamps
`#{field_id}_label` / `#{field_id}_hint` ids on the Control's own visible label
and hint and passes `aria: { labelledby:, describedby: }` through to the group
div — reusing the chrome sighted users see rather than inventing a naming API.
Every other kind gets `[{}, {}]`, and so does a checkbox group with neither a
label nor a hint.

## Escape hatches

`Input`, `Select`, `Textarea`, `Checkbox`, `Radio`, `Toggle`, `FileInput`,
`Hidden`, `Label`, `Control` (`builder.rb:137-191`), plus `hidden_field` — a
Rails-`FormBuilder`-compatible alias of `Hidden` for straight migration of
`form.hidden_field(:token, value: x)` call sites. They skip `Inference`
entirely; `Input` resolves its type from `resolve_input_type`, which consults
only the 16 positional `INPUT_TYPE_MODIFIERS` and the 26-key
`INPUT_TYPE_INFERENCE` attribute-name map, falling back to `:text`.

`row(columns:)` and `group(legend:)` are layout helpers rendering the `:row` and
`:group` roles.

## `Forms::Field` — the per-field context

`lib/forms/field.rb` (322 lines) knows one field's name, scope, model and error
set, and builds leaves with `name`/`id`/`value`/`error` wired in
(`field_attributes`, `field.rb:303-305`). Facts that bite:

- **`input` reroutes hidden.** `Field#input` returns `#hidden` when
  `type.to_s == "hidden"` (`field.rb:32-40`), so both `f.Input(:t, :hidden)` and
  `f.Input(:t, type: :hidden)` land on the bare leaf. daisyUI's
  `.input { display: inline-flex }` overrides WebKit's non-`!important`
  `input[type=hidden] { display: none }`, which makes a styled hidden field a
  visible, focusable tab stop in Safari.
- **`radio` drops the model value.** `field_attributes` carries
  `value: field_value`; `Field#radio` removes it before merging the radio's own
  positional value, and stamps `id: "#{field_id}_#{value}"`
  (`field.rb:80-91`) — otherwise every radio in a group renders the model's
  current value.
- **`field_value` is Ransack-safe.** It rescues `NoMethodError` but re-raises
  unless the receiver is the model and the missing name is this field's
  (`field.rb:206-214`), so a `method_missing`-backed getter still dispatches and
  a genuine typo inside the getter is not swallowed.
- **`invalid?` checks both names** — `@name` and `@error_name`
  (`field.rb:186-190`); `field_error_message` reads the first full message from
  either (`field.rb:307-311`).
- **`field_id` flattens a nested scope** — `@scope.tr('[', '_').delete(']')`,
  so `user[addresses_attributes][0]` becomes `user_addresses_attributes_0`
  (`field.rb:196-202`).
- **`checkbox_group` resolves items itself** (`field.rb:138-153`): `value:` is a
  Symbol or Proc; the per-item text is `item_label:` then `label:`, and when
  neither is given the first of `PhlexForms::Inference::LABEL_METHODS`
  (`name`, `title`, `label`, `to_s`) the item responds to. `item_label:` exists
  so `f.field(:tags, as: :checkbox_group, label: "Tags")` can put a heading on
  the Control and still customise item text. The leaf gets the resolved
  `{ value:, label:, checked:, id: }` array as `options:` — never the raw
  collection, and never the `value:`/`item_label:` resolvers, which are
  consumed here.
- **`theme` is the form's**, falling back to `Theme.resolve(nil)` when the host
  does not respond to `theme` (`field.rb:236-238`).

## The `<form>` element

`Form#initialize` (`form.rb:28-50`) derives:

- **scope** — `model_name.param_key`, else a String/Symbol as given, else
  `class.name.underscore.tr("/", "_")`. `scope: false` opts out entirely and
  emits bare field names (reactive row editors, `<template>`-cloned rows).
- **url** — `derive_url` (`form.rb:258-265`); for `model: [parent, child]` the
  record is the last element and the parents contribute `/parents/:id`
  segments.
- **method** — a caller's `method:` wins; otherwise `:patch` when the record is
  persisted, else `:post`. The element itself always uses `get`/`post` and a
  `_method` hidden field carries the rest (`form_method`, `method_field`).
- **enctype** — `multipart/form-data` on every non-GET form
  (`form_attributes`, `form.rb:193-206`), so a file input can never silently
  fail to upload.
- **CSRF** — only when `Phlex::Rails::Helpers::FormAuthenticityToken` is
  available and the method is not GET.

`live: true` on an inline form raises `ArgumentError` (`form.rb:30-35`): the
live endpoint rebuilds the component from its class, and a block cannot be
serialized. The message names the bound record's class, or the literal
`YourModel` when no model was passed.

### Nested attributes and collections

`fields_for` (`form.rb:100-114`) nests under `scope[assoc_attributes]`, or under
the raw name with `nested_attributes: false` for a JSONB/hash column. It indexes
only a **genuine** collection: `collection?` is `Enumerable && !Hash`
(`form.rb:171-173`) — a Hash responds to `each_with_index` but is one nested
record, and iterating it would emit `scope[assoc][0][field]`.

`collection_check_boxes` emits a leading empty-array hidden field then yields a
`CollectionCheckBoxBuilder` per item; `collection_select` maps the collection to
choice pairs and prepends `prompt:` as a blank-valued option.

## Related

- `../inference/summary.md` — what `field` asks the model
- `../theming/summary.md` — how a role becomes markup
- `../client-validation/summary.md`, `../live-validation/summary.md`
