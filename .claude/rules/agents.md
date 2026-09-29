# Agent Orchestration Rules

## Available Agents

| Agent | Purpose | When to Use |
|-------|---------|-------------|
| Explore | Codebase exploration (`model: haiku`) | Finding files, understanding patterns |
| Plan | Implementation planning (`model: sonnet`) | Complex features, architectural decisions |
| general-purpose | Multi-step tasks (`model: sonnet`) | Research, complex searches |
| fable-validator | Final validation (pinned to `fable`) | A finished change, before its pull request opens or merges |

## Immediate Agent Usage

Every agent spawned names its `model:`; one that does not runs on `sonnet` (`CLAUDE_CODE_SUBAGENT_MODEL` in `.claude/settings.json`).

Use agents PROACTIVELY without waiting for user prompt:

1. **Complex feature requests** -> Use Plan agent first
2. **Codebase exploration** -> Use Explore agent
3. **Multi-file searches** -> Use Explore agent (not direct Glob/Grep)
4. **Architectural decisions** -> Use Plan agent

## Parallel Execution

**ALWAYS** use parallel Task execution for independent operations:

```markdown
# GOOD: Parallel execution
Launch multiple agents simultaneously:
1. Agent 1: Explore the form-builder / field components
2. Agent 2: Trace the type-inference precedence in PhlexForms::Inference
3. Agent 3: Review test coverage

# BAD: Sequential when unnecessary
First explore, wait, then check specs, wait, then review...
```

## When to Use Explore Agent

Use the Explore agent (subagent_type=Explore) instead of direct Glob/Grep when:
- Open-ended codebase exploration
- Searching for patterns across the `Forms::` and `PhlexForms::` namespaces
- Answering questions about codebase structure
- Finding related implementations across modules

## When NOT to Use Agents

Use direct tools when:
- Reading a specific known file path
- Simple pattern match in known location
- Single-file edits
- Running specific commands
