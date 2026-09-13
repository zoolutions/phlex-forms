# phlex-forms

A model-bound form builder for [Phlex](https://www.phlex.fun), published as the
`phlex-forms` gem. One verb carries the library: `f.field :email` renders a
label, an input and an error-or-hint in a single call, with the control type,
the `required` flag, the choices and the label all read off the bound model
(`PhlexForms::Inference`). Components live under `Forms::` (a `Phlex::Kit`, so a
host that `include Forms` calls `Form(model:) { … }` bare); the machinery lives
under `PhlexForms::`. The same form class renders DaisyUI markup or bare
semantic HTML by swapping a theme, and a `Forms::Base` subclass can opt into
server-truth live validation over phlex-reactive or a client-side Stimulus
mirror of the model's own validators.

Three invariants govern every change:

1. **Everything degrades.** `daisyui` and `phlex-reactive` are soft dependencies
   (`require`-rescue-`LoadError` plus Zeitwerk `ignore`). The introspection
   paths — `PhlexForms::Inference`, `Forms::Field#required?`,
   `Forms::Field#field_value` — sit behind `respond_to?` guards and rescue to a
   safe default, so the gem boots and renders (Plain theme, attribute-name
   inference) for a PORO in a host that has neither gem installed. The
   deliberate exceptions are the Rails-parity helpers a caller opts into:
   `Form#time_zone_select` and `Form#collection_check_boxes` call
   `@model&.public_send(name)` directly, and `Inference.association_choices`
   calls `klass.all` from a lambda that runs outside `structural`'s rescue.
2. **A role, not a class.** A leaf component is reached through
   `PhlexForms::Theme[role]`, never by name, and every role is mapped in both
   `Theme.daisy` and `Theme.plain`. The leaf initializer signature
   (`*modifiers, name:, id:, value:, error:, required:, …`) is the seam that
   makes the two interchangeable.
3. **The caller always wins.** Inference is a default: an explicit `as:`, a
   positional type modifier, `choices:`, or any passed-through option beats
   anything read from the model, and validator-derived attributes merge
   underneath the caller's options.

The gem ships four runtime dependencies (`activesupport`, `glyphs`, `phlex`,
`zeitwerk`), a Rails engine that is loaded only when `Rails::Engine` is defined,
two RuboCop cops that host apps opt into, and a docs-kit site under `docs/` that
deploys from the same GitHub Release that publishes the gem.
