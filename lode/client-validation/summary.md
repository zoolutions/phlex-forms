# Client-side validation: mirroring the model's validators

Turned on with `Form(model:, validate: true)` (or `form_options validate: true`).
It is a **mirror**, not a replacement: the server's validators stay
authoritative, and the client only shortens the loop for the cases a browser can
reproduce.

## Server half

`Forms::Validations::Introspector` (`lib/forms/validations/introspector.rb`,
228 lines) reads a model class's validators and returns a `data:` hash per
attribute. `Introspector.for(model_or_class)` (`introspector.rb:51-58`) returns
`Introspector::Null` — whose `data_attributes_for` returns `{}` — for `nil` or
for anything that does not respond to `validators_on`, so callers never guard.
`Form#validations_introspector` (`form.rb:54-61`) memoises the real one when
`@validate` is set and the Null otherwise.

`SUPPORTED` maps **8** short validator class names to controller suffixes:
`PresenceValidator`, `LengthValidator`, `FormatValidator`,
`NumericalityValidator`, `InclusionValidator`, `ExclusionValidator`,
`ConfirmationValidator`, `AcceptanceValidator`. Matching on the **short** name
(`validator.class.name.split("::").last`) picks up both
`ActiveModel::Validations::*` and the parallel `ActiveRecord::Validations::*`
subclasses without listing both namespaces. A validator whose `:if`, `:unless`
or `:on` option is `present?` is rejected outright (`applicable_validators`,
`introspector.rb:110-114`) — a `.present?` test, where `Inference` and
`Forms::Field` use `options.key?` (`../inference/summary.md`).

### The attribute encoding

`data_attributes_for` (`introspector.rb:74-94`) returns
`{ controller: "validations--presence validations--length", … }` plus one key
per rule value. The value keys are built by `data_key`
(`introspector.rb:105-108`) as `:"validations__<suffix>_<key>_value"`: Phlex
rewrites `_` to `-` in a `data:` key, so `__` is how a literal `-` reaches the
HTML and `data-validations--length-maximum-value` comes out the other side.

`CONTROLLER_PREFIX = "validations"` is the single source of that identifier. It
matches the shipped controller path
(`app/javascript/phlex_forms/controllers/validations/<suffix>_controller.js`),
so `lazyLoadControllersFrom("phlex_forms/controllers")` resolves
`validations--length` to the right file. `Form#apply_validation_coordinator`
derives the form-level identifier from the same constant —
`"#{CONTROLLER_PREFIX}--form"` (`form.rb:211-224`) — so field and form
identifiers cannot drift.

Per-validator value builders: `presence` → `required: "true"`; `length` →
`maximum`/`minimum`/`is`, with `in:`/`within:` expanded to `minimum`+`maximum`;
`format` → the regex translated for JS (`\A`/`\z`/`\Z` → `^`/`$`, a
`(?-mix:…)` wrapper stripped) plus `i`/`m` flags; `numericality` → the 9
`NUMERICALITY_KEYS`; `inclusion`/`exclusion` → the list as JSON;
`confirmation` → `match: "<attr>_confirmation"`; `acceptance` → the accepted
values as JSON, defaulting to `%w[1 true]`. `allow_blank` rides along on
`length`, `format`, `numericality`, `inclusion` and `exclusion`; `allow_nil`
only on `length` and `numericality`.

### Inline rules without a model

`Forms::Validations::ManualRules` (`lib/forms/validations/manual_rules.rb`, 77
lines) takes `{ length: {...}, presence: true, … }`, builds a throwaway
`ActiveModel` class whose validators reproduce the rules, and delegates to the
Introspector — so the per-validator → data-attribute conversion exists in one
place. Reached through `f.field(:x, validate: { length: { maximum: 60 } })`.

That ad-hoc class always names its attribute `:value`
(`manual_rules.rb:34, 47`), which is invisible for every rule except
`confirmation:` — it emits `match: "value_confirmation"` whatever the real field
is called, so inline confirmation rules only work on a field actually named
`value`.

### The per-field merge seam

`Forms::Field#apply_validations` (`field.rb:225-232`) is the seam that carries
both the Stimulus data and (under `live`) the blur trigger. `field` routes
through it (`builder.rb:81`), and so do six escape hatches — `Input`, `Select`,
`Textarea`, `Checkbox`, `Toggle`, `FileInput`. The other four — `Radio`,
`Hidden`/`hidden_field`, `Label`, `Control` — call the leaf directly and get no
client validation and no live trigger.

`validate: false` opts a field out, `validate: true` uses the form-level
introspector, a Hash means inline rules, and anything else yields `{}`
(`validation_data_for`, `field.rb:250-256`). Merging is key-aware:
`TOKEN_JOINED_DATA_KEYS` (`:controller`, `:action`) are **joined** with a space
rather than replaced (`merge_data`, `field.rb:266-276`), which is what lets a
validation controller, a live trigger and a caller-supplied controller coexist
on one element.

## Form-level wiring

`apply_validation_coordinator` (`form.rb:211-224`) adds three things to the
`<form>`: the `validations--form` controller, the `submit->validations--form#onSubmit`
action (without it the controller connects but never intercepts), and
`novalidate` — the Stimulus layer owns error display, so the native browser UI
is turned off. Both the controller list and the action list are appended to
whatever the caller passed.

## Client half

10 files under `app/javascript/phlex_forms/controllers/validations/`: the 8
field validators, the shared `base_controller.js`, and `form_controller.js`.

`FieldValidatorController` (`base_controller.js`, 166 lines) attaches to the
input itself, listens for `blur` and for the synthetic
`invalidate:validations` event, and asks the subclass's `check(value)`.
Details that matter:

- Errors are stored per validator on the element
  (`element.__formsValidationErrors[identifier]`), so one validator reporting
  valid cannot erase another's message. The element shows the first message in
  sorted-identifier order, not all of them — the order is sorted purely so the
  displayed text does not flicker between renders.
- The error slot is the Stimulus `error` target when the page pre-rendered one;
  otherwise the controller reuses, or creates, a
  `<p data-validations--error="<id>">` adjacent to the input. The attribute is
  set with `setAttribute` because `dataset` rejects keys containing `--`.
- The error class is chosen per tag — `textarea-error`, `select-error`, else
  `input-error` — rather than adding all three.

`form_controller.js` (43 lines) intercepts `submit`, dispatches
`invalidate:validations` to every **non-disabled** `input`/`textarea`/`select`
whose `data-controller` names a `validations--*` other than the coordinator,
collects errors into `event.detail.errors`, and on any error cancels the submit
and focuses plus scrolls to the first one. The coordinator knows nothing about
which validators exist — a new validator is a new field controller and nothing
here.

Messages come from `app/javascript/phlex_forms/i18n.js` (40 lines), which reads
the locale off `<html lang>`, falls back to a `<meta name="locale">` then `en`,
and lets a host override any string via `window.PhlexForms.messages`. The
bundled table (`messages.js`, 100 lines) ships **en, fr and af** — a different
set from the gem's Ruby locales (`en`, `sv`, `de` under `config/locales/`), so
a Swedish or German host gets translated submit buttons and English client-side
validation messages.

## Related

- `../live-validation/summary.md` — the server-truth alternative, which merges
  through the same `apply_validations` seam
- `../inference/summary.md` — the other reader of the same validator objects
