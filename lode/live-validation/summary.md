# Live validation: the form as a reactive component

`Forms::Live` (`lib/forms/live.rb`, 223 lines) makes a whole form one
phlex-reactive component. Blur on any input, plus a debounced form-wide `input`
event, POSTs every field to one `:validate` action that assigns a whitelisted
slice to the model, runs the **real** ActiveModel validators — uniqueness,
`:if`/`:unless`, `confirmation`, `:on` contexts all work — and replies with a
focus-preserving morph. **Nothing is ever persisted.**

## Only a `Forms::Base` subclass can be live

`Forms::Base.live(model:, scope: nil, debounce: 300)` (`base.rb:55-66`) raises
`PhlexForms::FeatureUnavailable` when phlex-reactive is absent, naming the form
class (or the literal `this form` for an anonymous class), then
`include Forms::Live` and calls `setup_live`. An inline
`Form(model:, live: …)` raises `ArgumentError` instead (`form.rb:30-35`): the
endpoint rebuilds the component from its class, and a caller's block cannot be
serialized. `reactive_available?` (`base.rb:69-71`) is factored out purely so a
spec can drive the guard.

`setup_live` (`live.rb:45-58`) declares `reactive_state :model_gid, :touched`,
the `:validate` action with its param schema, and — guarded by `respond_to?` so
older phlex-reactive still loads — `skip_verify_authorized :validate`.
phlex-reactive >= 0.11 defaults `verify_authorized` on and raises
`AuthorizationNotVerified` for an action that never authorizes; `:validate` is a
deliberate no-persist read-only pass, so it opts out rather than pretending.

## Identity is state, not a reactive record

The signed token carries `model_gid` and `touched` (`live.rb:130-138`):

- `model_gid` is the model's GlobalID **only when persisted**
  (`signed_model_gid?`, `live.rb:204-206`) — `reactive_record` cannot round-trip
  an unsaved draft, so a new record rebuilds as `live_model_class.new`
  (`locate_live_model`, `live.rb:198-202`).
- `touched` is the list of field names the user has left. `field_object`
  (`live.rb:185-192`) passes `errors: nil` for an untouched field, so nothing
  flashes red before the user has finished typing. A form re-rendered after a
  failed classic submit arrives with errors already on the model, so the
  constructor unions in `@errors.attribute_names` (`live.rb:137`) and those
  surface without a touch.

`#id` (`live.rb:141-143`) is the Streamable contract: `@options[:id]` or
`"<edit|new>_<scope>"`.

## The `:validate` action

`validate(_touch: nil, **posted)` (`live.rb:149-154`) adds `_touch` to the
touched set, assigns, validates, and replies `morph`. The wire key is `_touch`
— underscored so it can never collide with a model attribute. The posted
attributes arrive under the form's scope, declared with the custom
`:form_attributes` param type, which passes a Hash through and `DROP`s anything
else (`register_param_type!`, `live.rb:36-42`). That type is registered from an
engine initializer because phlex-reactive freezes its registry after boot
(`engine.rb:38-40`); the spec suite registers it in `spec_helper.rb:22`.

### The assignment whitelist

`assign_live_attributes` (`live.rb:210-221`) writes only through public setters
the model responds to, and only for permitted keys. The default permit set is
derived (`derived_live_attributes`, `live.rb:111-124`): every
`attribute_names` entry, every validated attribute, and the
`<attr>_confirmation` twin of any `ConfirmationValidator`. `live_permit` replaces
that set and a declared `live_tags` name is unioned in, but `live_deny` is
subtracted **last** (`live_permitted_attributes`, `live.rb:98-103`), so
`live_deny :tags` does remove a lifted tag field from the permit set.
Class-level readers fall back up the superclass chain through `inherited_live`,
so a subclassed live form inherits its parent's configuration.

## Live tag fields

phlex-reactive's tag controller reads **one** `data-reactive-tags-field` per
reactive root, so a live form can lift **at most one** tag field onto its root;
a second `live_tags` call raises `ArgumentError` telling you to render it as a
standalone (non-live) `field :x, as: :tags` (`live.rb:84-94`).

`Forms::Live#form_attributes` (`live.rb:160-181`) mixes onto the `<form>`: the
reactive root, the debounced `on(:validate, event: "input")` trigger, and — when
a tag field is declared — `reactive_tags(name: field_name(tag))` and
`reactive_filter(input: "#<query id>")`, deriving both through the same
`field_name`/`field_id` path the widget uses so the selectors match.

`Forms::Live::Field` (`lib/forms/live/field.rb`, 46 lines) is the per-field
half. It merges the blur trigger into the input's `data:` through
`apply_validations` — the same seam the client-side mirror uses, and therefore
reaching only the builder methods that call it
(`../client-validation/summary.md`) — and it overrides `tag_field` so that
**only** the declared `live_tags` field renders the rootless variant
(`live/field.rb:26-37`); any other tag field falls through to the self-rooted,
non-live widget. Call-site `suggestions:` win over the declaration's unless they
are empty or nil (`blank_suggestions?`).

Rendering rootless is what makes live tags work at all: with no nested reactive
root, the hidden tags input's nearest root ancestor is the `<form>`, so the
form owns the field and `:validate` collects it.

## Soft-dependency surface

`lib/phlex_forms.rb:96-103` `ignore`s six paths when `Phlex::Reactive` is
undefined — `forms/live.rb`, `forms/live/`, `forms/tag_field.rb`,
`forms/plain/tag_field.rb`, `forms/rootless_tag_field.rb`,
`forms/plain/rootless_tag_field.rb` — because each includes or inherits from a
class that includes `Phlex::Reactive::Component` / `ClientBindings` at class
level and so cannot even load. `Theme` correspondingly omits the `tag_field`
roles (`../theming/summary.md`).

## Related

- `../client-validation/summary.md` — the Stimulus mirror, and the shared
  `apply_validations` merge seam
- `../packaging/summary.md` — the engine initializers
