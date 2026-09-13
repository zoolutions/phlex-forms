# The docs site (`docs/`)

A self-contained [docs-kit](https://github.com/zoolutions/docs-kit) Rails app
that documents the gem and **dogfoods it**: `docs/Gemfile:14` path-depends on
`..` and fully requires it, so pages render live examples of the real
components (the interactive tag field on `/docs/tag-fields`). It has its own
bundle, its own Ruby (`docs/.ruby-version`: 4.0.5, against the gem's floor of
3.4), its own `.rubocop.yml`, and its own committed `Gemfile.lock` and
`bun.lock`. Deployed to <https://phlex-forms.zoolutions.llc>.

## Page → behaviour map

Pages are registered in `docs/app/models/doc.rb` — one `page "Title", group:`
line each, 16 lines, 16 page classes under `docs/app/views/docs/pages/`. A page
with no registry line is **not routed and not in the nav**; a registry line
whose view class does not resolve is silently skipped everywhere. `rails g
docs_kit:page "Title" --group=…` writes both halves.

| When you change… | Update |
|---|---|
| the `field` verb, its options, an `as:` kind | `field_api.rb`, `quick_start.rb` |
| `PhlexForms::Inference` (precedence, a new mapping) | `inference.rb` |
| `Forms::Base`, `form_options`, the `live` macro's class side | `form_classes.rb` |
| a theme role, a Plain twin, `Theme#with` | `theming.rb` |
| `ClassMerge`, `field_variants`, a daisy modifier | `variants.rb` |
| `row`/`group` | `layout.rb` |
| the tag field, `live_tags` | `tag_fields.rb` |
| `Forms::Live` behaviour | `live_validation.rb` |
| the Introspector, a Stimulus validator | `client_validation.rb` |
| `fields_for`, `collection_check_boxes`, `collection_select`, `checkbox_group` | `nested_collections.rb` |
| an escape hatch (`Input`, `Control`, …) | `escape_hatches.rb` |
| `PhlexForms::Configuration` | `configuration.rb` |
| either cop | `rubocop_cops.rb` |
| installation, engine wiring, importmap pins | `installation.rb`, `overview.rb` |

The README (461 lines) covers the same surface and drifts independently — a
user-facing change updates **both**.

## Authoring contract

`docs/AGENTS.md` carries the docs-kit block, and `docs/.claude/skills/
write-docs-page/SKILL.md` is the Claude Code skill for it. The rules that bite:

- `DocsUI::Section` owns structure and the "On this page" TOC. A Markdown `##`
  is never page structure — only a sub-heading inside a Section.
- Prose is `md <<~'MD'` — **single-quoted** heredoc, so `#{…}` stays literal
  (Phlex escapes author text; never `html_safe`).
- Positional primary argument, keyword modifiers: `Section("Title",
  description:)`, `Code(source, filename:)`.
- The page must read with JavaScript off; the one `docs-nav` controller only
  enhances.
- `DocsKit.configuration.themes` (`config/initializers/docs_kit.rb:22`) and the
  `@plugin "daisyui" { themes: … }` list in
  `app/assets/stylesheets/application.tailwind.css` must name the same nine
  themes (`dark light synthwave retro cyberpunk dracula night nord sunset`).
  Adding one means adding both.
- No inline `rubocop:disable` to force layout.

## The CSS build and its generated file

`bin/build-css` resolves `daisyui`, `docs-kit` and `phlex-forms` with
`bundle show` and writes their `**/*.rb` globs into
`app/assets/stylesheets/tailwind.sources.css`, which
`application.tailwind.css` imports, then runs `bunx @tailwindcss/cli`. It
fails fast if any of the three cannot be resolved — a silently missing
`@source` ships an unstyled site. `phlex-forms` is in that list because the
docs render real gem components whose literal class strings Tailwind must see.

`tailwind.sources.css` is **committed output**. Every build path regenerates it,
but the committed paths still have to be real — see `../review/docs-site.md`.
`bun run build:css` / `watch:css` wrap the script; `lib/tasks/build_css.rake`
hooks `css:build` onto `assets:precompile` for Docker and production.

## Running and checking it

From inside `docs/` (never the repo root — separate bundle):

```
bin/dev            # execs `bin/rails server` — it does NOT read Procfile.dev,
                   # so run `bun run watch:css` yourself in a second shell
bin/rubocop        # its own config, inheriting rubocop-rails-omakase + docs-kit
bin/ci             # ActiveSupport::ContinuousIntegration: setup, rubocop,
                   # bundler-audit, bin/importmap audit, brakeman
```

`docs/config/ci.rb` defines those five steps. There is **no RSpec suite in
`docs/`** and no GitHub workflow that runs `bin/ci` — the only automated docs
job is `deploy-docs.yml` on a release.

## Deploy

`deploy-docs.yml` (release published, or manual dispatch) calls docs-kit's
reusable `deploy.yml@main` with `image: zoolutions/phlex-forms` and
`service: phlex-forms`. `docs/config/deploy.yml` is the dash config:
`minimum_version: 4.0.7`, Cloudflare Tunnel plus dash-proxy, health check on
`/up`, status pages served from `public/`. Because the deploy is
release-triggered, the site is only ever as new as the last gem release.

## Related

- `../review/docs-site.md` — the accepted review rule about the generated CSS
- `../packaging/summary.md` — the release that triggers the deploy
