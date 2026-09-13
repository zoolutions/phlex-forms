# Practices

Patterns this codebase follows that `.claude/rules/` does not already state.
The rules own the basics — file size, `respond_to?` guards, literal class
strings, soft dependencies, delegation to the `daisyui` gem, TDD, conventional
commits, the release path. Read `.claude/rules/coding-style.md`,
`.claude/rules/testing.md` and `.claude/rules/git-workflow.md` first; this file
is the rest.

## A comment that explains a non-obvious choice cites its issue

Fifteen comments across ten files carry the issue that forced the behaviour —
`(issue #9)`, `(issue #13)`, `(#168)` for an upstream phlex-reactive issue,
`zazu#2934` for a bug found in a consuming app. They are load-bearing: without
`(issue #13)` the `field_attributes.except(:value)` in `Field#radio` reads like
a defensive habit instead of the fix for every radio rendering the model's
current value. A comment that says *why* with no issue is fine; a comment that
restates the next line is not.

## Add a role, not a class

A new control kind is four coordinated edits, in this order:

1. the leaf under `lib/forms/`, honouring the binding contract
   (`*modifiers, name:, id:, value:, error:, disabled:, required:`);
2. a `Forms::Plain::` twin — a **subclass** that overrides only rendering, so
   the binding logic exists once (`lode/theming/summary.md`);
3. both maps in `PhlexForms::Theme` (`Theme.daisy` **and** `Theme.plain`), or
   `reactive_roles` if it needs phlex-reactive;
4. a `Forms::Field` builder method that assembles it from `field_attributes`,
   and a `render_field_input` branch if `field` should reach it by `as:`.

Skipping (2) or (3) is the failure mode: the daisy path renders and the plain
path raises `KeyError` at request time, where no spec looks unless a theme-parity
example exists.

## Styling seams beat a rewritten template

When a Plain twin would have to copy a complex `view_template` to restyle it,
extract the class strings into small reader methods on the daisy leaf and let
the twin override those instead. `Forms::TagField` (seven seams) and
`Forms::CheckboxGroup` (four) are the precedent; the markup then cannot drift
between themes because there is only one copy of it.

## Options flow through `apply_validations`, and `data:` merges by key

`Forms::Field#apply_validations` is where a field's `data:` accumulates — the
Stimulus validation attributes, the live blur trigger, and whatever the caller
passed. `merge_data` joins `:controller` and `:action` with a space
(`TOKEN_JOINED_DATA_KEYS`) and replaces everything else. Anything that needs to
add a Stimulus controller to a field goes through this seam; writing
`data: { controller: … }` directly silently drops the others.

## A missing soft dependency raises a sentence, not a `NameError`

`PhlexForms::FeatureUnavailable` messages name the gem, the Gemfile line to add,
and the working alternative — `Theme.daisy` points at the plain theme,
`Base.live` points at `validate: true`. A guard that returns `nil` or lets a
`NameError` escape is the wrong shape: the caller asked for the feature
explicitly.

## Derived values are `Data`, not hashes

`PhlexForms::Inference::Result` is a `Data.define` with a `.blank` constructor
and `.with` for the incremental refinements each inference step makes. A new
multi-valued return from an internal module follows it rather than returning a
hash whose keys are documented in a comment.

## Endless defs for one-line readers

`def field_name(name) = @scope ? "#{@scope}[#{name}]" : name.to_s`,
`def group_classes = VARIANT_CLASSES.fetch(…)`. Used consistently for the
styling seams and the Rails-parity accessors; a method with a guard clause or a
rescue is written out.

## A user-facing change lands with its changelog entry and its docs page

One PR carries the code, a `CHANGELOG.md` entry under the right existing
`###` subsection (`lode/review/changelog.md`), and the `docs/` page that
describes the behaviour (`lode/docs-site/summary.md` has the map). The README
covers the same surface as the docs site and drifts independently — check it
too.

## Related

- `lode/workflow.md` — the commands, branches, CI and conflict rules
- `lode/review/` — accepted review findings as rules
