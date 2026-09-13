# Inference: what the model is asked, and in what order

`PhlexForms::Inference` (`lib/phlex_forms/inference.rb`, 238 lines) is a
`module_function` module with no state. It is pure introspection: every model
touch on the eager path is `respond_to?`-gated, and the two methods that walk a
model (`structural`, `from_column`) rescue `StandardError` to `nil`
(`inference.rb:81-88`, `130-142`), as does `validator_attributes`
(`191-209`). A PORO, a Struct or an untyped ActiveModel therefore falls through
to the attribute-name map rather than raising. ActiveRecord is never required.

The one unguarded touch is `association_choices` (`inference.rb:171-177`), which
calls `klass.all` and `record.public_send(label_method)`. It runs from the
lambda `association` returns, so `Builder#materialize_choices` calls it long
after `structural`'s rescue has returned — an exception there reaches the
caller.

## The Result

`Result = Data.define(:as, :name, :label, :choices, :attributes, :multiple,
:required)` with a `.blank(as:, name:)` constructor (`inference.rb:23-27`).
`name` is the attribute the input renders under, which is not always the name
the caller passed.

## Precedence — first hit wins

`base_result` (`inference.rb:61-71`):

| # | Source | Wins because |
|---|---|---|
| 1 | explicit `as:` | the caller always wins |
| 2 | a positional modifier in `Builder::INPUT_TYPE_MODIFIERS` (16 symbols) | `f.field :price, :number` |
| 3 | `choices:` present → `:select` | passing choices is asking for a select |
| 4 | model structure — rich text, attachment, enum, `belongs_to` | ground truth about the column's meaning |
| 5 | column type via `COLUMN_TYPE_MAP` (9 entries) | ground truth about its shape |
| 6 | `Builder::INPUT_TYPE_INFERENCE` attribute-name map (26 keys) | `email`, `phone`, `birthday` … |
| 7 | `:text` | |

Steps 4 and 5 **and** the validator attributes are skipped entirely when
`PhlexForms.config.infer_from_model` is false: `base_result` returns
`name_map_result` straight away (`inference.rb:68`) and `resolve` returns before
merging validator attributes (`inference.rb:53`). Steps 1-3 and the name map
still apply — the knob turns off *model* inference, not all of it.

## Step 4 in detail (`structural`, `inference.rb:81-88`)

Tried in this order, first non-nil wins:

1. **rich text** — a `rich_text_<name>` association exists (ActionText's
   `has_rich_text`) → `:rich_textarea`.
2. **attachment** — `reflect_on_attachment(name)` → `:file`, with
   `multiple: true` when the macro is `:has_many_attached`.
3. **enum** — `defined_enums` has the name → `:select` over
   `[key.humanize, key]` pairs.
4. **association** — `reflect_on_association` for the name **or** the name minus
   a `_id` suffix, matching only a non-polymorphic `belongs_to`
   (`inference.rb:118-128`). The result rewrites `name` to
   `reflection.foreign_key`, takes its label from `human_attribute_name`, and
   marks `required` from the association's own presence validators. Its
   `choices` is a **lambda** — `-> { association_choices(reflection.klass) }` —
   so `klass.all` is only loaded when the caller passed no `choices:`;
   `Builder#field` calls it through `materialize_choices`. The option text comes
   from the first of `LABEL_METHODS` (`name`, `title`, `label`, `to_s`) the
   **first** record responds to — it is memoised with `||=` and reused for every
   record — and each option's value is `record.id`.

`column_type` (`inference.rb:144-153`) prefers `type_for_attribute` and falls
back to `attribute_types`, so a plain `ActiveModel::Attributes` class works
without ActiveRecord. A `:number` from an integer column carries `step: 1`; a
decimal or float carries `(10 ** -scale).to_f` when the type reports a scale and
the String `"any"` when it reports none (`step_for`, `inference.rb:155-162`).

`COLUMN_TYPE_MAP` covers non-string columns only — a `:string` column has no
entry, so it falls through to the name map, which is what disambiguates
`email`/`password`/`phone` from a plain text field.

## Validator-derived attributes (`resolve`, `inference.rb:51-59`)

Merged **orthogonally** and **underneath** whatever `base_result` produced:
`result.with(attributes: validator_attrs.merge(result.attributes))`. Two
validators contribute:

- `LengthValidator#options[:maximum]` → `maxlength`, but only for the 7
  `TEXT_LIKE` kinds (`text email password tel url search textarea`).
- `NumericalityValidator` → `min`/`max`, but only when the kind is `:number`.
  Inclusive bounds map directly; an exclusive bound maps to ±1 **only** with
  `only_integer`, and is otherwise skipped — `greater_than: 0.5` has no correct
  HTML equivalent (`numericality_attributes`, `inference.rb:211-225`).

Any validator carrying `:if`, `:unless` or `:on` is skipped (`conditional?`,
`inference.rb:234-236`), and the same predicate gates `presence_validated?`
(`inference.rb:179-186`): those need server context the browser does not have.

## Where the same logic lives three times

"Conditional validator" and "has a presence validator" are written out in three
places, never shared:

| Where | Methods | Test |
|---|---|---|
| `PhlexForms::Inference` | `presence_validated?` (`inference.rb:179-186`), `conditional?` (`234-236`) | `options.key?` |
| `Forms::Field` | `required?` (`field.rb:176-184`), `conditional?` (`278-280`) | `options.key?` |
| `Forms::Validations::Introspector` | `applicable_validators` (`introspector.rb:110-114`), `conditional?` (`116-119`) | `options[…].present?` |

The Introspector's `.present?` test is the odd one: a validator written
`validates :x, presence: true, if: nil` is skipped by inference and by
`required?` but still mirrored to the client. A change to what "conditional"
means has to touch all three.

## Related

- `../form-api/summary.md` — how `field` consumes a `Result`
- `../client-validation/summary.md` — the other reader of the same validators
