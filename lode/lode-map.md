# Lode map

The repository's durable memory. Read this first; each file below is one topic
and states the system as it is.

## Baseline

| File | Purpose |
|---|---|
| [`summary.md`](summary.md) | what phlex-forms is, and the three invariants every change is measured against |
| [`terminology.md`](terminology.md) | the vocabulary — builder, role, leaf, Plain twin, binding contract, touched, rootless |
| [`practices.md`](practices.md) | patterns not already in `.claude/rules/`: issue-citing comments, adding a role, styling seams, the `apply_validations` seam |
| [`workflow.md`](workflow.md) | the profile the shared `/lode:` workflow skills read — commands, branches, layers, shapes, constraints, docs, CI, flakes, conflicts, verification |
| [`plans/README.md`](plans/README.md) | where a plan artifact goes |

## Subsystems

| File | Purpose |
|---|---|
| [`form-api/summary.md`](form-api/summary.md) | `PhlexForms::Builder` and its three hosts, what one `field` call does, the `as:` dispatch, `Forms::Field`, the `<form>` element, nested attributes |
| [`inference/summary.md`](inference/summary.md) | the precedence chain, what the model is asked and in what order, validator-derived attributes, the three copies of "conditional validator" |
| [`theming/summary.md`](theming/summary.md) | roles → leaf classes, the 19 (+2 reactive) roles, the binding contract, Plain twins, `DelegatedField`, `ClassMerge`, the literal-class-string rule, icons |
| [`client-validation/summary.md`](client-validation/summary.md) | `validate: true` — the Introspector, the `data-validations--*` encoding, inline `ManualRules`, the per-field merge seam, the ten Stimulus controllers |
| [`live-validation/summary.md`](live-validation/summary.md) | `live model:` — the `:validate` action, signed `model_gid`/`touched` state, the assignment whitelist, live tag fields, the phlex-reactive soft-dependency surface |
| [`packaging/summary.md`](packaging/summary.md) | boot order, the two Zeitwerk roots, the engine's four initializers, the gemspec, the two RuboCop cops, `bin/release` → `rake release`, the three workflows |
| [`testing/summary.md`](testing/summary.md) | the three spec layers, the four global helpers, the one global reset, what is covered and what is not |
| [`docs-site/summary.md`](docs-site/summary.md) | the docs-kit app under `docs/` — page registry, the behaviour → page map, the authoring contract, the CSS build, the deploy |

## Review rules

Accepted review findings, written as rules about the system. `/lode:gate`
enforces them before a push; `/lode:learn` adds to them.

| File | Covers |
|---|---|
| [`review/docs-site.md`](review/docs-site.md) | the generated `tailwind.sources.css` and its `@source` paths |
| [`review/changelog.md`](review/changelog.md) | one `###` subsection per category per release heading |

## Not in the lode

`lode/tmp/` is gitignored scratch space for a run's evidence. The standing
rules live in `.claude/rules/` (coding style, testing, git workflow, agents) and
`CLAUDE.md`; this directory describes the system, not the process of changing
it — except `workflow.md`, which is the bridge.
