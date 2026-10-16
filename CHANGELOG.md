# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.5.0] - 2026-10-15

### Upgrading to 0.5

The configuration is frozen once the app has booted, so threads and fibers
read one immutable value, and so can Ractors when every setting can be shared
(#42, conformance-kit; see the unshareable-value note below).

- **It finalizes on its own.** Under Rails the engine calls
  `PhlexForms.finalize!` in `after_initialize`, after every initializer has
  run, with no app code. Without Rails, `PhlexForms.configure` finalizes when
  its block returns; a host that never calls `configure` (or loads Rails
  without booting an app) calls `PhlexForms.finalize!` at boot.
- **A direct write after boot raises `FrozenError`.** `PhlexForms.config.infer_from_model = false`
  in a Rails initializer still works. After boot (a test's `before` block, or
  after `configure` outside Rails), write through `PhlexForms.configure`
  instead: it edits a copy and swaps it in.
- **Finalizing never raises over a value it cannot share.** The value is kept
  as given and works on the main Ractor only: an icon renderer lambda at the
  top level of an initializer (its `self` is `main`, and it may close over a
  logger) is one. Define it in a class or module body (or with
  `Ractor.shareable_lambda` on Ruby 4.0) to keep the whole configuration
  shareable. A renderer that is not a Proc (an object with `#call`, a
  `Method`) is never copied or frozen, so one that keeps a cache still works.
- **`form_options` and the `live` macros keep frozen copies** of what they are
  given, so the values nested in `form_defaults` and the live settings are
  frozen. Your own arrays and hashes are copied, never frozen.

### Added

- **`PhlexForms.finalize!`**: freezes the configuration and stores
  Ractor-shareable copies of its settings. Idempotent; returns the
  configuration. `PhlexForms::Theme::DAISY` / `PLAIN` are the built-in themes,
  built once when the theme loads (`Theme.daisy` / `Theme.plain` return them),
  and every `Theme` is frozen.
- **Ractor support for the non-rendering paths.** On Ruby 4.0, field
  inference, option resolution, theme resolution, the icon renderer and the
  `form_options` / `live` settings work inside a non-main Ractor. Rendering
  there waits on Phlex
  ([yippee-fun/phlex#1055](https://github.com/yippee-fun/phlex/pull/1055)).
- **conformance-kit 0.4 gates in CI**: the thread-safety RuboCop cops, thread
  and fiber contention specs, a Ractor canary and a strict
  `conformance-audit` of `PhlexForms` and `Forms` with nothing allowlisted.

### Changed

- **The configuration is frozen after boot** (see Upgrading to 0.5).
  `Configuration` sets every default in `initialize`; no reader memoizes. The
  default icon renderer and `Configuration.glyphs_renderer` are shareable.
- `rich_textarea` renders `<lexxy-editor>` through Phlex's `tag` instead of
  `register_element`; the markup is the same.

### Fixed

- **The themes build without phlex-reactive.** `Theme.daisy` named
  `Forms::TagField` before checking for the soft dependency, so a host without
  phlex-reactive got `NameError: uninitialized constant Forms::TagField` on its
  first form.
- **`Theme.daisy` / `Theme.plain` are built once.** Two threads resolving a
  theme for the first time could each build their own.
- **phlex-forms loads without Rails with phlex-reactive bundled.** phlex-reactive's
  `Sortable` calls `Hash#to_json` while it loads without requiring json, so a
  plain Ruby host got `NoMethodError` on its first form (and, with finalizing,
  from `configure`). phlex-forms requires json before phlex-reactive.

## [0.4.1] - 2026-10-14

### Fixed

- **Client-side validators honour the validator's `message:`** (issue #41).
  `validates :code, format: { with: /\A[a-z]*\z/, message: "lowercase only" }`
  used to show the generic "is invalid" in the browser and the specific text
  only after a round trip. The introspector now emits
  `data-validations--<validator>-message-value`: a String as is (`%{count}`
  stays for the browser to fill), a Symbol resolved on the server through
  ActiveModel's lookup chain in the current locale, a Proc skipped (it needs a
  record). Length's `too_long:` / `too_short:` / `wrong_length:` win over
  `message:`, as on the server. Every shipped controller prefers the value and
  falls back to its bundled message; the submit coordinator collects it too. A
  `validate: { presence: { message: "…" } }` / `confirmation: { message: "…" }`
  rules hash now keeps its options (it used to collapse them to `true`).

## [0.4.0] - 2026-09-30

### Upgrading to 0.4

phlex-forms now depends on **daisyui `~> 2.0`** and merges every default +
caller `class:` through `DaisyUI::ClassMerge` (a port of tailwind_merge 1.5.6
plus daisyUI's modifier groups). `PhlexForms::ClassMerge` is gone.

- **Bundle daisyui 2.** It's a hard dependency now, so a `gem "daisyui", "~> 1.x"`
  pin in your Gemfile must move to 2.x (or be dropped).
- **Register your custom Tailwind utilities.** The old merger only knew daisy
  sizes/colors and `w-*`, and passed everything else through. The new one
  classifies every utility, so an unregistered custom one can be dropped as a
  conflict. For example, a `text-h1` you pass next to `FieldError`'s
  `text-error` reads as a colour:

  ```ruby
  # config/initializers/daisy_ui.rb
  DaisyUI.configure do |config|
    config.class_merge.utility("text-h1", like: "text-lg")
  end
  ```

- **`CollectionCheckBox` merges a caller `class:` instead of replacing its
  base class.** `class: "checkbox-primary"` now renders `checkbox
  checkbox-primary` (it used to drop `checkbox`). A caller who used `class:` to
  swap the base class entirely (`class: "toggle"`) now gets both classes.
- **More conflicts resolve now.** A caller's `mt-4` / `text-xs` replaces a
  component's default `mt-1` / `text-sm` instead of stacking beside it.
- **Daisy leaves lean on daisyui's own merge.** Input, Select, Textarea and the
  other delegated leaves hand `class:` to the daisyui component, so
  `DaisyUI.configure { |c| c.class_merge.enabled = false }` applies to them too.
  The components that render plain HTML (FieldHint, FieldError, Row, Form,
  FormControl, TagField, ChoicesSelect) merge through `DaisyUI::ClassMerge.merge`
  directly, which that switch doesn't affect.

### Removed

- **`PhlexForms::ClassMerge`**: use `DaisyUI::ClassMerge.merge`.
- **The daisyui soft-dependency path.** `require "phlex_forms"` loads daisyui
  unconditionally, the daisy theme is always the default, and `Theme.daisy` no
  longer raises `FeatureUnavailable`. The Plain theme is unchanged and still
  emits zero daisy classes.

## [0.3.1] - 2026-09-09

### Fixed

- **`rich_textarea` forwards its block into `<lexxy-editor>`**: Lexxy configures
  an editor through CHILD elements — `<lexxy-prompt>` for @mentions,
  `<lexxy-code-language-picker>` for code blocks — but the component rendered
  the element with no block and `Form#rich_textarea` never forwarded one, so
  `f.rich_textarea(:content) { ... }` silently dropped its content. A host
  could wire @mentions and get an editor that never prompts, with no error
  anywhere (a host app's mention endpoint 500'd for months unnoticed, because
  nothing ever called it).
- **`rich_textarea` wires Active Storage's direct-upload endpoints**: Lexxy
  uploads attachments through `data-direct-upload-url` /
  `data-blob-url-template` on the element. Lexxy's own Rails tag helper sets
  them; this component built the element itself and did not, so rich text
  editors silently lost image uploads. Set as PATHS (a multi-host app must not
  pin uploads to whichever host rendered the page first), fully guarded — no
  Rails dependency is introduced, and a caller-supplied value always wins.

## [0.3.0] - 2026-08-12

### Fixed

- **`FileInput` multiple uploads submit an array** (Rails `file_field` parity):
  with `multiple:` set, the input name now gets `[]` appended (unless already
  present), for the standalone component, the `Plain` variant, and the form
  builder path. Without it the browser collapsed a multi-file selection into
  ONE scalar param, which a host app's `params.expect(attr: [])` silently
  discarded — uploads no-opped with a success response.

## [0.2.9] - 2026-07-16

### Fixed

- **A caller width class stacked with the `w-full` default instead of replacing
  it**: `DelegatedField#width_class` joined `"w-full"` and the caller's
  `class:` verbatim, so `Forms::Select(class: "w-36")` emitted
  `class="... w-full w-36"` and stylesheet source order — not author intent —
  picked the winner (in practice `w-full`, which blew filter selects up to full
  width; zazu#2934). `ClassMerge` gained a width family (anchored `w-*`, so
  `min-w-*`/`max-w-*` still compose) and `width_class` merges through it —
  last width wins, matching the daisyui size/color family semantics.

## [0.2.8] - 2026-07-11

### Added

- **`hidden_field`** (#21): a snake_case alias of `f.Hidden` for Rails
  `FormBuilder` migrations, on inline forms and `fields_for` builders. An
  explicit `value:` still wins over the model's value.

## [0.2.7] - 2026-07-11

### Changed

- **`tag_field` uses phlex-reactive 0.12.2's escape-hatch sugar**
  (`reactive_tags` / `reactive_filter`) (#20): the wire name is validated at
  render, and the client-side type-ahead filter runs again (under
  phlex-reactive 0.12.x only one of its two selectors was emitted, so it never
  ran).

## [0.2.6] - 2026-07-11

### Added

- **`checkbox_group` `item_label:`** — the per-item text accessor, so a
  `f.field(:tags, as: :checkbox_group, label: "Tags", item_label: ->(t){…})`
  renders a visible group heading (`label:`, via the Control) AND custom item
  labels at once — previously `label:` on the `f.field` path was eaten by the
  heading and items fell back to `to_s`. `item_label:` wins over `label:` for the
  item text; on the bare verb `label:` stays the item accessor and `item_label:`
  is an alias. Absent it, behavior is unchanged.

## [0.2.5] - 2026-07-11

### Added

- **`checkbox_group` accessible name** (issue #17): the `div[role="group"]` can
  now carry an accessible name/description. HTML/ARIA attributes pass straight
  through to the group, so the bare verb is named with plain `aria:`
  (`aria: { label: "Tags" }` or `aria: { labelledby: "id" }`); through `f.field`
  the Control's own visible `label:` / `hint:` get stable ids and the field wires
  `aria-labelledby` / `aria-describedby` at them (no duplicate markup). Absent a
  name, output is unchanged.

## [0.2.4] - 2026-07-11

### Added

- **`checkbox_group` — batched checkbox group for array-valued fields** (the
  tag/facet-picker shape): `f.checkbox_group(:tag_ids, Tag.all, value: :id,
  label: :name, variant: :pill, size: :sm)`, or via field inference
  (`f.field :tag_ids, as: :checkbox_group, collection: Tag.all, value: :id`).
  Shares one array-valued field name with a leading empty-array hidden field,
  derives the checked set from the model's current value, and renders under both
  themes. `variant:` (`:stack`/`:inline`/`:pill`) is layout-only, no JS.

### Changed

- **Client-side validation Stimulus identifiers dropped the `forms--` prefix**:
  the bundled controllers now emit `validations--presence`, `validations--length`,
  … (and the `validations--form` coordinator) so
  `lazyLoadControllersFrom("phlex_forms/controllers")` resolves them to their
  shipped path `phlex_forms/controllers/validations/*_controller` — previously
  `forms--validations--*` derived `.../forms/validations/*`, which 404'd and the
  controllers never connected (issue #12). The `data-validations--*` binding
  attributes and the `invalidate:validations` event changed to match. Hosts that
  registered `forms--validations--*` explicitly must update the identifier.

### Fixed

- **`f.Radio` / `Field#radio` rendered the model's current value on every radio
  instead of each radio's own value**: `field_attributes` carried `value:
  field_value` and was splatted after the explicit positional value, clobbering
  it — a new record lost the value entirely, an edit form gave every radio the
  same value. `radio` now drops `field_attributes`' `value` (issue #13).
- **`Form(validate: true)` never fired client-side validation on submit**: the
  coordinator controller was attached but no `data-action` wired its `onSubmit`
  handler, so submitting an invalid form was not blocked. `apply_validation_coordinator`
  now emits `submit->validations--form#onSubmit` (joined with any
  caller-supplied `data-action`).
- **`fields_for` iterated a Hash-backed association (JSONB), emitting bogus
  indices**: a Hash responds to `#each_with_index`, so a JSONB column rendered
  with `nested_attributes: false` produced `scope[assoc][0][field]`, `[1]`, …
  instead of a single `scope[assoc][field]`. It is now treated as a single
  nested scope; only genuine collections (Enumerable, not Hash) iterate.

## [0.2.3] - 2026-07-08

### Added

- **`tag_field`** (#7): `f.field :tags, as: :tags, suggestions: [...]`, a
  model-bound tag/chip control composed from phlex-reactive's client-only tag
  primitives. It submits one comma-joined param; `live_tags` validates it
  inside a `live` form.

## [0.2.2] - 2026-07-08

### Fixed

- **`Forms::TimeZoneSelect` raised at render time** (#5): `NoMethodError` for
  `time_zone_options_for_select` (called on the `DaisyUI::Select` receiver)
  and `Phlex::ArgumentError: Expected a String` (an HTML-safe buffer passed to
  `safe`). It was broken in 0.2.0 and 0.2.1.

## [0.2.1] - 2026-07-08

### Added

- **Rails form-builder compat aliases** (#4): `Forms::Form#object` (`model`),
  `#object_name` (`scope`) and `#[]` (`field_object`), and
  `Forms::FieldsForBuilder#object` / `#[]`, for call sites migrating off an
  ActionView `FormBuilder`.

## [0.2.0] - 2026-07-08

### Added

- **`Forms::Base` declarative form classes**: subclass, declare fields in
  `#fields` where `self` IS the form (bare `field :email`, no `f.` prefix),
  render with `render UserForm.new(model: @user)`. Class-level `form_options`
  defaults are inherited and merged down the subclass chain; a render-time
  block appends after the declared fields.
- **`live` server-truth validation** (`Forms::Base` only, phlex-reactive soft
  dependency): `live model: User` runs the real ActiveModel validators
  server-side on blur/debounced input — uniqueness, `:if`/`:unless`,
  confirmation, `:on` context — and morphs errors back in with focus
  preserved. Touched-field tracking rides the signed reactive state; nothing
  is persisted. Inline `Form(live: true)` raises with guidance.
- **Model-driven type inference** in `field`: boolean column → toggle, AR enum
  → humanized select, non-polymorphic `belongs_to` → association select (name
  rewritten to the foreign key, errors still surface from the association
  name), text column → textarea, date/datetime/time/numeric columns → matching
  inputs (+`step`), `has_rich_text` → rich textarea, attachments → file
  (`multiple` + `name[]` for `has_many_attached`), length/numericality
  validators → `maxlength`/`min`/`max`. Explicit `as:`/`choices:`/positional
  type modifiers always win; POROs and untyped models behave exactly as
  before. Kill-switch: `PhlexForms.config.infer_from_model = false`.
- `choices:` without `as: :select` now implies a select (previously silently
  dropped).
- **Themes**: component roles resolve through `PhlexForms::Theme`. The daisy
  theme (default when the daisyui gem is loaded) is unchanged; the new Plain
  theme renders bare semantic HTML — same binding contract, variants accepted
  and ignored, `aria-invalid` + `role="alert"` + `data-field-error/hint`
  hooks, zero styling classes — so the same form class renders in non-daisyui
  projects. Select per form (`theme:`), per class (`form_options theme:`), or
  globally; override single roles with `Theme#with`.
- **Form-level variant defaults**: `field_variants: [:primary, :sm]` on a
  form / `form_options` / `PhlexForms.config.field_variants` prepends daisyui
  variants to every `field`'s inner input (call-site modifiers stack last).
- Layout helpers: `f.row(columns:)` (responsive grid) and `f.group(legend:)`
  (fieldset), available on inline forms and `fields_for` builders.
- Adoption enablers: `Form(scope: false)` emits bare field names (reactive row
  editors, `<template>` rows); `fields_for(..., nested_attributes: false)`
  skips the `_attributes` suffix (JSONB columns); public `Form#field_value`
  joins `field_name`/`field_id` for external widgets.

### Changed

- **Minimum Ruby is now 3.4** (was 3.2). The optional `live` validation runs on
  phlex-reactive, which has required Ruby >= 3.4 since its 0.9 line; aligning the
  floor keeps the whole gem installable wherever the live integration is.
- **`daisyui` is now a soft dependency** (removed from the gemspec). With it
  loaded nothing changes; without it the Plain theme is the default and the
  gem renders unstyled semantic HTML.
- **Live validation is compatible with phlex-reactive >= 0.11's default-ON
  `verify_authorized` (#168).** The `:validate` action declares
  `skip_verify_authorized` — it's a no-persist, read-only validation pass, so it
  needs no authorization call and won't raise `AuthorizationNotVerified`. No host
  action required.
- Model-driven inference changes rendered output for ActiveRecord-backed
  forms that previously fell through to a text input. Before/after:

  | field on an AR model | before | after |
  | --- | --- | --- |
  | boolean column | `<input type="text">` | toggle (checkbox + hidden pair) |
  | text column | `<input type="text">` | `<textarea>` |
  | AR enum | text input | `<select>` with humanized options |
  | `belongs_to` (`:country`/`:country_id`) | text input | `<select>` over the association, `name="…[country_id]"` |
  | date/datetime/time column | text input (unless name-mapped) | matching input type |
  | integer/decimal/float column | text input | `<input type="number" step=…>` |
  | attachment / rich text | text input | file input / rich textarea |

  Pass `as:` explicitly or set `PhlexForms.config.infer_from_model = false`
  to keep the old rendering.

## [0.1.0] - 2026-07-07

### Added

- Initial extraction of the `Forms::` Phlex form builder from the Cosmos apps.
- Control-first builder API: `f.field :email, label:, hint:, as:, choices:`
  renders label + input + error/hint in one call, inferring input type and the
  `required` flag from the model.
- Escape-hatch component API preserved: `f.Input`, `f.Select`, `f.Textarea`,
  `f.Checkbox`, `f.Toggle`, `f.FileInput`, `f.Hidden`, `f.Label`, `f.Control`,
  `f.submit`.
- Configurable icon renderer (`PhlexForms.configure`) with a zero-dependency
  inline-SVG default and optional `glyps` auto-detection.
- Polymorphic array model support in `Form(model: [parent, child])`.
- Bundled Stimulus controllers (choices, searchable-select, time zone) and
  default `en`/`sv`/`de` locales, wired through an optional Rails engine.
