# Plans

Where a plan artifact goes in this repository.

**Default: a GitHub issue** on `zoolutions/phlex-forms`. Implementation then runs
against the issue number, and the PR closes it with a `Closes #N` keyword in the
body (see `../workflow.md`, Branches and PRs).

**A file instead**, when the plan is too long or too provisional for an issue:
`docs/plans/YYYY-MM-DD-<slug>.md`. That directory does not exist yet — create it
on first use. It sits inside the docs-kit Rails app but outside everything the
app loads: `docs/.rubocop.yml` lints only `app/`, `config/`, `Rakefile` and
`config.ru`, pages are routed from `docs/app/models/doc.rb` alone, and the
Docker build copies but never reads it. Leave a plan file uncommitted unless the
user asks for it in the branch.

Nothing here moves existing plans; there are none.
