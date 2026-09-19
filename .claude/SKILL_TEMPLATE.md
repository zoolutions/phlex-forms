# Command Template

Use this template when creating a new slash command for phlex-forms. See
`.claude/README.md` for the full authoring guide.

Copy the content below into `.claude/commands/{name}.md`, then fill it in.

Pick the model tier by the work the command does: `haiku` for mechanical/config
work, `sonnet` for prescriptive pattern-following passes, `opus` for
orchestration, security, review synthesis, and reasoning-heavy specialists.
Always use the tier alias, never a full model ID — aliases track the latest model
in the tier. Pin `fable` only on read-only planning commands that hand execution
to cheaper models (see `/plan`); otherwise choose it per-session with `/model`.

```markdown
---
model: sonnet
description: "{Action verbs describing what it does}. Use when {trigger phrases, contexts, file types}."
argument-hint: "{example input the user might provide}"
allowed-tools: {optional — narrow the tool allowlist, e.g. Bash(gh pr view:*), Read, Grep}
---

# {Command Title}

{One or two sentences: what this command is for and the mental model.}

## When to Use

- {Trigger context 1}
- {Trigger context 2}

## Workflow

1. {Step}
2. {Step}

## Project invariants to respect

- **Guard every model touch** — `respond_to?`-gate introspection and rescue to a safe default; POROs must degrade (see `Forms::Field#required?` / `PhlexForms::Inference`).
- **Route field types through inference** — new input types wire into `PhlexForms::Inference`'s precedence, not ad-hoc branches.
- **Resolve classes through the theme** — components render under BOTH `:daisy` and `:plain`; no hardcoded class strings, and every daisy leaf needs a `Forms::Plain::*` twin.
- **Literal class strings** — Tailwind/daisy classes are scanner-visible; never interpolate.
- **daisyui and phlex-reactive are soft deps** — capability-gate each (require-rescue-LoadError + Zeitwerk ignore); phlex-reactive backs only `Forms::Live`.

## Verification

```bash
bundle exec rspec
bundle exec rubocop lib spec
```

## Checklist

- [ ] {Success criterion}
- [ ] `bundle exec rubocop lib spec` passes
```

After creating the file, add a row to the "Slash Commands" table in the repo
`AGENTS.md` so the command is discoverable and its tier is recorded.
