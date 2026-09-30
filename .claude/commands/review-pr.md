---
description: Review a GitHub pull request for code quality, patterns, and best practices
model: opus
argument-hint: "PR URL or number (e.g., 5 or https://github.com/mhenrixon/phlex-forms/pull/5)"
---

# PR Review

Review a PR for pattern compliance and issues. Be concise.

## Workflow

1. Fetch PR details and diff via `mcp__github__pull_request_read`
2. Categorize files by layer (config, inference, theme, components, plain fallback, live/reactive, engine, cops, docs)
3. Check for pattern violations
4. Output a structured review

## Pattern Violations to Check

```text
# WRONG -> RIGHT
Hardcoded class string in a component      -> Resolve through the theme / PhlexForms::Theme
New field type bypasses inference          -> Wire into PhlexForms::Inference (respect the precedence table)
Interpolated Tailwind/daisy class          -> Literal, scanner-visible class strings (no #{...})
Component doesn't honor the Plain theme    -> Must render under BOTH :daisy and :plain
Model touch with no respond_to? guard      -> Inference/#required? must degrade for POROs (rescue StandardError -> nil)
Hard require of daisyui / phlex-reactive   -> Soft dep: require-rescue-LoadError + Zeitwerk ignore
Reimplementing a daisy leaf's markup       -> Delegate to the daisyui gem via DelegatedField
raw()/html_safe on model/param free text   -> Let Phlex escape text
Manual gem push                            -> bin/release (CI publishes)
```

## Output Format

```
## Files Requiring Manual Review

| File | Reason |
|------|--------|
| lib/phlex_forms/inference.rb | Precedence change — verify the first-hit-wins order and PORO fallthrough |
| lib/phlex_forms/configuration.rb | New knob — verify default + backwards compat |
| lib/forms/plain/... | Plain-theme parity — the field must render under both themes |

## Critical Issues

- `lib/forms/field.rb:NN` - Model value inserted without escaping / no respond_to? guard
- `lib/phlex_forms/configuration.rb:NN` - New knob has no default (changes existing behavior)

## Suggestions (non-blocking)

- Consider extracting X

## Verdict

**Request Changes** | **Approve** | **Comment** — one-line justification
```

## Tools

```text
mcp__github__pull_request_read
  method: "get"        -> PR details
  method: "get_diff"   -> Changes
  method: "get_files"  -> File list
  method: "get_status" -> CI status

bundle exec rubocop lib spec -> Style checks
bundle exec rspec            -> Tests
```
