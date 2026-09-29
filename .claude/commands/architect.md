---
description: "Coordinates a change across the phlex-forms layers. Use when planning a feature that spans the builder API, the leaf components, inference, theming, and config."
model: opus
argument-hint: "feature or task to coordinate"
---

# phlex-forms Architect Mode

You are in **Architect Mode** — coordinating a change across all phlex-forms layers.

## Why this exists

A phlex-forms feature usually touches several layers in a specific order. Tackle
them out of order and you miss integration points (e.g. add a leaf component that
a theme must map before the theme role exists), infer a control the leaf can't
render, or add a config knob nothing reads. The stable seam is the leaf
initializer signature — `(*modifiers, name:, id:, value:, error:, required:, ...)`
— so the same form class renders under any theme; break that and every layer
above shifts.

## The layers

```
Layer 1: Builder API        lib/phlex_forms/builder.rb (the `field` primary verb + PascalCase escape hatches),
                            lib/forms/form.rb (inline Form), lib/forms/base.rb (declarative Forms::Base classes)
Layer 2: Leaf components     lib/forms/*.rb (Input, Select, Textarea, Checkbox, Toggle, Radio, FileInput, ...),
                            each delegating markup to the daisyui gem via PhlexForms::DelegatedField
Layer 3: Type inference      lib/phlex_forms/inference.rb (column/enum/association/validator -> control type + attrs)
Layer 4: Theming             lib/phlex_forms/theme.rb (role -> component map; :daisy default, :plain fallback),
                            the Forms::Plain::* components (lib/forms/plain/)
Layer 5: Live validation     lib/forms/live.rb (phlex-reactive integration; a soft dependency),
                            app/javascript/phlex_forms/controllers/validations/ (Stimulus client-side validation)
Layer 6: Config + engine     lib/phlex_forms/configuration.rb (theme, infer_from_model, field_variants, icon_renderer),
                            lib/phlex_forms/engine.rb (optional Rails wiring: importmap, i18n, live param type)
```

## Typical implementation flow (bottom-up)

1. **Config** — add the knob (with a sensible default) to `PhlexForms::Configuration` if the feature is tunable
2. **Inference** — extend `PhlexForms::Inference` if a new model shape should map to a control (respect the precedence order)
3. **Leaf component** — add/extend the `Forms::*` leaf, delegating markup to the daisyui gem via `PhlexForms::DelegatedField`
4. **Theme** — map the new role in BOTH `Theme.daisy` and `Theme.plain` (a role with no plain fallback breaks the unstyled theme)
5. **Builder API** — expose it through `field` (primary verb) and/or a PascalCase escape hatch on the builder surface
6. **Live/reactive** — only if the feature needs client enhancement (Stimulus validation controller, or `Forms::Live` wiring)
7. **Engine** — wire optional Rails integration (importmap path, i18n load path, live param type) if the feature needs it
8. **Specs + docs** — tests at every touched layer; update the README

## Delegate vs. do directly

**Delegate** (Explore/Plan agents; pass `model: haiku`/`sonnet` for mechanical
reads) when: multiple files change, you need to sweep how the daisyui gem exposes
a component, or the work is cleanly scoped to one layer.

**Directly** when: a single-file change, or a cross-cutting concern (the leaf
initializer contract, the inference precedence order, the daisy/plain theme
parity) you must hold in your head.

## Decision guide

| Decision | Use When |
|----------|----------|
| New config option | Feature needs globally-configurable behavior (theme, variants, icon renderer, inference toggle) |
| New `Forms::` leaf | A new control type is needed (must delegate markup to the daisyui gem) |
| Extend `Inference` | A new model shape (column type, enum, association, validator) should map to a control |
| New theme role | A new leaf must be selectable per-form/per-class/globally |
| Live / Stimulus change | The feature needs client-only enhancement (validation, reactive re-render) |
| Engine change | Optional Rails wiring (importmap, i18n, phlex-reactive param type) is required |

## Integration points

| When working on... | Also consider... |
|--------------------|------------------|
| A leaf reading new config | the `Configuration` default; behavior when the host never sets it |
| A new inference rule | the precedence order (explicit `as:` > positional modifier > `choices:` > model shape > column type > name map); the `infer_from_model` kill-switch |
| A new leaf component | mapping it in BOTH `Theme.daisy` and `Theme.plain`; the shared leaf initializer signature |
| The daisy theme | the matching `Forms::Plain::*` fallback (variants accepted-and-ignored, aria/data hooks only) |
| `Forms::Live` | that phlex-reactive is a SOFT dependency (guard with `defined?(Phlex::Reactive)`); the `Engine` param-type initializer |
| A required setup step | the README, and (for live/reactive concerns) the `PhlexForms::Engine` initializer — there is NO install generator |
| Config or a public API | the README; backwards compatibility for hosts that never configure |

## Common mistakes

| Wrong | Right |
|-------|-------|
| Start with the leaf component | Start with the inference rule / config knob it depends on |
| Hardcode a value in a component | Read from `PhlexForms.config` |
| Hand-write raw daisyUI markup | Delegate to the daisyui gem via `PhlexForms::DelegatedField` |
| Add a daisy leaf, forget the plain one | Map the role in BOTH `Theme.daisy` and `Theme.plain` |
| Hard-require phlex-reactive | Guard `Forms::Live` behind `defined?(Phlex::Reactive)` |
| Add an inference rule ahead of an explicit option | Respect precedence: caller-passed options always win |
| Document setup in README only | Also wire the `PhlexForms::Engine` initializer if it's a live/reactive concern |

## Verification checklist

- [ ] Implementation order planned (bottom-up)
- [ ] Config default set; hosts that never configure are unaffected (backwards compatible)
- [ ] New leaf mapped in BOTH `Theme.daisy` and `Theme.plain`
- [ ] Inference precedence respected; `infer_from_model` kill-switch honored
- [ ] Live/reactive features guard the soft phlex-reactive dependency
- [ ] Tests cover every touched layer (`spec/forms/**` integration, `spec/phlex_forms/**` unit)
- [ ] `bundle exec rubocop lib spec` + `bundle exec rspec` pass

## Handoff

Run the `fable-validator` agent on the combined diff first. On BLOCK do not open or merge: mark it `needs-user` and report the blockers instead of calling it ready.

Summarize: the layer-ordered plan, files per layer, integration points, the
theme-parity story (daisy AND plain), the soft-dependency story for anything
live/reactive, and the architectural decisions made.

Now coordinate the change with this architectural perspective.
