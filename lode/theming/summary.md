# Theming: roles, leaves, and the two themes

## A theme is a frozen role → class map

`PhlexForms::Theme` (`lib/phlex_forms/theme.rb`, 99 lines) wraps one Hash.
`#[]` `fetch`es and raises `KeyError` listing the known roles
(`theme.rb:27-31`); `#with(**overrides)` returns a new theme, so a host can
replace a single leaf: `PhlexForms::Theme.resolve(:plain).with(input: MyInput)`.

`Theme.resolve(value)` (`theme.rb:38-47`) accepts a `Theme`, `:daisy`,
`:plain`, or `nil` meaning `PhlexForms.config.theme`; anything else raises
`ArgumentError`. `Configuration#theme` defaults to `Theme.daisy` when `DaisyUI`
is defined and `Theme.plain` otherwise (`configuration.rb:57-59`), and
`Theme.daisy` raises `PhlexForms::FeatureUnavailable` if the gem is absent
(`theme.rb:50-54`) — so asking for daisy explicitly in a host without the gem
fails loudly instead of rendering unstyled.

Selection points, most local last: `PhlexForms.configure { |c| c.theme = … }` →
`form_options theme: :plain` → `Form(model:, theme: :plain)`. The form resolves
once in its initializer (`form.rb:40`) and `Forms::Field` reads it back through
the form (`field.rb:236-238`).

## The roles

Both themes map the same **19** roles literally: `input`, `select`,
`choices_select`, `textarea`, `rich_textarea`, `checkbox`, `toggle`, `radio`,
`checkbox_group`, `file`, `wrapped_input`, `hidden`, `control`, `label`,
`field_error`, `field_hint`, `submit`, `row`, `group`. Two more —
`tag_field` and `rootless_tag_field` — are added by `reactive_roles`
(`theme.rb:92-96`) **only when `Phlex::Reactive` is defined**, so a host without
phlex-reactive gets the theme's own `KeyError` rather than a `NameError` on an
unloaded class. That makes 21 roles in a reactive host, 19 without.

`Forms::` also holds components no role points at — `EmailField`,
`PasswordField`, `Range`, `TimeZoneSelect`, `CollectionCheckBox`,
`CollectionLabel` — reached by name from the kit or from `Form`'s Rails-parity
helpers, and therefore not theme-swappable.

Four roles are deliberately shared or re-pointed rather than twinned one-to-one:

| Role | daisy | plain | Why |
|---|---|---|---|
| `hidden` | `Forms::Hidden` | `Forms::Hidden` | a hidden field has no styling, no variants and no error state |
| `choices_select` | `Forms::ChoicesSelect` | `Forms::Plain::Select` | no choices.js in the plain theme; it swallows `searchable:` |
| `rich_textarea` | `Forms::RichTextarea` | `Forms::Plain::Textarea` | rich text needs an editor integration the plain theme does not ship |
| `toggle` | `Forms::Toggle` | `Forms::Plain::Checkbox` | a toggle is a styled checkbox |

## The binding contract

A leaf's initializer keywords are the seam: `*modifiers, name:, id:, value:,
error:, disabled:, required:` plus per-leaf extras. All 17 `Forms::Plain::*`
classes are **subclasses** of their daisy leaf, so the binding logic is written
once and cannot drift. They override rendering in one of two ways:

- **14 override `view_template`** — `Plain::Checkbox`, `Control`, `FieldError`,
  `FieldHint`, `FileInput`, `Group`, `Input`, `Label`, `Radio`, `Row`, `Select`
  (which also swallows `searchable:` in its own `initialize`), `Submit`,
  `Textarea`, `WrappedInput`. `Forms::Plain::Checkbox` still emits the hidden
  unchecked-value input, because that is binding, not styling.
- **3 override only styling seams and reuse the inherited template** —
  `Plain::TagField`, `Plain::RootlessTagField`, `Plain::CheckboxGroup`. Their
  markup can never drift between themes because there is only one copy of it:

  - `Forms::TagField` exposes `root_classes`, `list_classes`, `menu_classes`,
    `option_classes`, `chip_classes`, `remove_classes`, `input_classes`
    (`tag_field.rb:132-138`). `Forms::Plain::TagField` overrides all seven:
    `root_classes` becomes the bare hook `"tag-field"`, `input_classes` becomes
    the caller's own `class:`, and the other five become `nil`.
    `Forms::RootlessTagField` reuses `#body` verbatim and only drops the
    reactive-root `<div>`, and `Forms::Plain::RootlessTagField` repeats the same
    seven overrides (Ruby has no multiple inheritance to share them).
  - `Forms::CheckboxGroup` exposes `render_checkbox`, `group_classes`,
    `item_classes`, `item_label_classes` (`checkbox_group.rb:82-102`); the Plain
    twin overrides those four, replacing the DaisyUI-delegated checkbox with a
    bare `<input type="checkbox">`.

## Delegation (`PhlexForms::DelegatedField`)

`lib/phlex_forms/delegated_field.rb` (71 lines) is included by the daisy leaves
that wrap a `daisyui` gem component. A leaf sets `@modifiers`, `@error`,
`@disabled`, `@required`, `@full_width`, `@attributes`, then calls:

- `normalize_modifiers` — drops `IGNORED_MODIFIERS` (`:bordered`, a daisyUI v4
  no-op in v5) so v4-era call sites keep working.
- `daisy_modifiers` — appends `:error` when the field is invalid **and** the
  caller did not already pass the `:error` modifier itself
  (`delegated_field.rb:23-27`). A different colour modifier (`:primary`) does
  not suppress it — the check is `@modifiers.include?(:error)`, not "any
  colour" — so an invalid `:primary` field renders `[:primary, :error]`.
- `binding_attributes(**extra)` — `name`/`id`/`class` plus the caller's
  passthrough attributes minus `:error`, `:value`, `:class`, with `disabled`
  and `required` added only when true, then `compact`ed.
- `unstyled_attributes(**extra)` — the Plain variant: caller classes verbatim,
  no width class, and `aria-invalid: true` instead of a colour modifier.

`width_class` (`delegated_field.rb:48-52`) returns the caller's `class:`
untouched unless `@full_width`; with it, it merges `"w-full"` and the caller's
`class:` through `ClassMerge` rather than joining them, so a caller's `w-36`
**replaces** the default instead of leaving stylesheet source order to pick.

## `PhlexForms::ClassMerge`

`lib/phlex_forms/class_merge.rb` (66 lines). Three families are mutually
exclusive and resolved last-token-wins: `SIZE` (`-xs|sm|md|lg|xl` suffix),
`COLOR` (`-primary|secondary|accent|neutral|info|success|warning|error`
suffix), and `WIDTH` (anchored `\Aw-`, so `min-w-*`/`max-w-*` compose freely).
A family key is namespaced by the token's prefix — `input-sm` and `select-sm`
are different families — and `WIDTH` is tested first so a `w-*` token can never
be mis-bucketed (`family_key`, `class_merge.rb:56-64`). Anything the three
patterns do not match passes through in order. There is deliberately no
`tailwind_merge` dependency: these are the only conflicts form fields produce.

## The class-string rule

Class strings must be **literal and greppable**: a host's Tailwind scanner reads
the gem's `.rb` files, so a name built with `#{…}` is invisible to it and the
style never ships. Variant maps are therefore literal tables —
`Forms::Row::COLUMN_CLASSES`, `Forms::CheckboxGroup::VARIANT_CLASSES` — and a
daisy leaf hands its size/colour modifiers to the `daisyui` gem rather than
composing a class name. `Forms::ChoicesSelect` is the exception that proves it:
choices.js replaces the element, so its size and colour ride as
`data-choices-size-value` / `data-choices-color-value` for the controller to
apply, never as classes (`choices_select.rb:63-82`).

## Icons

`Configuration#icon_renderer` defaults to a lambda calling
`PhlexForms::InlineIcons.render`, a one-entry map (`chevron-down`) returning a
raw SVG String; an unknown name returns `""` rather than raising. `glyphs` is a
hard dependency but **not** the default renderer — it resolves SVGs from the
host's rails_icons asset tree, which a minimal host has not set up, so it is
opt-in via `PhlexForms::Configuration.glyphs_renderer` (`configuration.rb:28-35`).

## Related

- `../form-api/summary.md` — who asks for a role
- `../packaging/summary.md` — why the reactive-gated leaves are not autoloaded
