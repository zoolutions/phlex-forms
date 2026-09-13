# Packaging: boot, autoloading, the engine, the cops, the release

## Boot order (`lib/phlex_forms.rb`, 110 lines)

1. `date` and three ActiveSupport core-ext requires (`object/blank`,
   `enumerable`, `string`), then `phlex`, `glyphs`, `zeitwerk`
   (`phlex_forms.rb:3-9`).
2. `require "daisy_ui"` and `require "phlex/reactive"`, each in a
   `begin/rescue LoadError` with a comment saying what is lost
   (`phlex_forms.rb:11-26`).
3. `require_relative "phlex_forms/version"` — before Zeitwerk, and ignored by
   it.
4. `module PhlexForms` with `Error < StandardError`,
   `FeatureUnavailable < Error`, and the `configuration` / `config` /
   `configure` / `reset_configuration!` singletons.
5. `module Forms; extend Phlex::Kit; end` — this is what makes every
   `Forms::Foo` callable as a bare `Foo(...)` in a host that `include Forms`.
6. Zeitwerk, below.
7. `require_relative "phlex_forms/engine" if defined?(Rails::Engine)`.

`lib/phlex-forms.rb` is a 4-line alias so `require "phlex-forms"` works; RuboCop
`Naming/FileName` excludes it.

## Two sibling autoload roots

```
lib/phlex_forms  ->  PhlexForms::   (config, inference, theme, class_merge, …)
lib/forms        ->  Forms::        (the component kit)
```

They are **siblings, not nested** (`phlex_forms.rb:82-83`), which is why the
loader is driven manually instead of `Zeitwerk::Loader.for_gem` — the component
root has to map onto a top-level `Forms` while the internals stay under
`PhlexForms`. The inflector teaches it `phlex_forms`/`phlex-forms` →
`PhlexForms`.

Four paths are ignored unconditionally (`phlex_forms.rb:86-91`):
`phlex_forms/version.rb` (already required), `lib/rubocop` and
`phlex_forms/rubocop.rb` (they open the `RuboCop::` namespace and load on
demand from a host's `.rubocop.yml`), and `phlex_forms/engine.rb` (required
conditionally at the bottom, so Zeitwerk must not eager-load it).

Six more are ignored when `Phlex::Reactive` is undefined — see
`../live-validation/summary.md`.

## The engine

`PhlexForms::Engine` (`lib/phlex_forms/engine.rb`, 42 lines) is assets-and-
locales only: no `isolate_namespace`, no routes, models or helpers. Four
initializers:

| Initializer | Does |
|---|---|
| `phlex_forms.assets` | appends `app/javascript` to `config.assets.paths` if the app has an assets config |
| `phlex_forms.importmap` (`before: "importmap"`) | appends `config/importmap.rb` to `importmap.paths` and `app/javascript` to `cache_sweepers`, each `respond_to?`-guarded |
| `phlex_forms.i18n` | `unshift`s the gem's `config/locales/*.yml` onto `I18n.load_path`, so a host app's own keys win |
| `phlex_forms.live_param_type` | `Forms::Live.register_param_type!` when phlex-reactive is present — the registry freezes after boot |

`config/importmap.rb` pins the bundled controllers with `pin_all_from` under
`phlex_forms/controllers`, plus `phlex_forms/i18n` and `phlex_forms/messages`
by hand. Ruby locale files ship for `en`, `sv` and `de`; the JavaScript message
table bundles `en`, `fr` and `af` instead
(`../client-validation/summary.md`).

## The gemspec

`phlex-forms.gemspec`: Ruby `>= 3.4`, four runtime dependencies —
`activesupport (>= 7.0, < 9)`, `glyphs (>= 0.2.0, < 1)`,
`phlex (~> 2.0, >= 2.0.0)`, `zeitwerk (~> 2.6)`. Both `daisyui` and
`phlex-reactive` are deliberately absent; `glyphs` is present but is **not** the
default icon renderer (`../theming/summary.md`).

`s.files` uses `git ls-files` with a `Dir` glob fallback for a checkout without
`.git`, and both branches must ship the same four prefixes — `exe/`, `lib/`,
`app/`, `config/` — plus `CHANGELOG.md`, `LICENSE.txt`, `README.md`. `app/`
carries the Stimulus controllers and `config/` the importmap and locales, so
dropping either publishes a gem whose engine wires up nothing.

The gem's own `Gemfile.lock` is **gitignored** — correct for a library, and the
reason `rake release` never stages it.

## The RuboCop cops

Opt-in for host apps: `require: phlex_forms/rubocop` plus `inherit_gem:
phlex-forms: config/rubocop.yml`, which enables both cops scoped to
`app/components/**/*.rb` and `app/views/**/*.rb`.

- `PhlexForms/RawForm` (51 lines, autocorrecting) rewrites `form_with` and a raw
  `form(...)` element to `Form`. It deliberately skips a bare `form` with no
  arguments and no block — that is a variable or method reference
  (`form.label(...)`), not a Phlex element.
- `PhlexForms/LegacyFormMethod` (103 lines, message only) flags 12 Rails
  `*_field` methods and 11 other legacy names on a receiver named `form`, `f`,
  `af` or anything matching `/_form\z/`, suggesting `form.field(...)` first and
  the PascalCase escape hatch second.

## Release

`bin/release` (111 lines) → `rake release[X.Y.Z]` (`Rakefile:37-190`).

`bin/release` computes the next version from `lib/phlex_forms/version.rb` (the
source of truth, not the newest tag), shows the commits since the last tag, and
confirms. Arguments: `patch` (default) / `minor` / `major` / an explicit
`X.Y.Z` or `vX.Y.Z`, plus `list`, `--dry-run`/`-n`, `--force`/`-f`, `--help`.

`rake release` aborts unless the branch is `main` and the tree is clean, then:
bumps the version file; string-edits **only** the `phlex-forms (X.Y.Z)` pin in
`docs/Gemfile.lock` (a full `bundle install` there can fail on that lockfile's
broad `PLATFORMS` list, which would abort a release); `gem build --strict`;
commits `chore: bump version to X.Y.Z`; pushes `main`; and creates the GitHub
Release. Every step is idempotent — an unchanged version, an already-pushed
`main` or an existing release is skipped, not repeated.

Two extra modes: `rake release[X.Y.Z,force]` deletes the existing release and
tag first so a re-cut points at the current `main`, and `rake release[pre]`
re-releases the version already in the file as a GitHub prerelease. Publishing
is entirely CI's job — never `gem push` by hand.

## CI

Three workflows, all in `.github/workflows/`:

- `main.yml` — on push to `main` and on every PR. `Lint` (`bundle exec rubocop
  lib spec`, Ruby 4.0) and `Specs (Ruby 3.4 | 4.0)` (`bundle exec rspec`),
  `fail-fast: false`.
- `release.yml` — on a published release. `test` (rspec on 3.4) → `build`
  (verifies the tag matches `PhlexForms::VERSION`, `gem build --strict`, fails
  if the packed gem contains any `.git*`, `*.gemspec`, `spec/` or `test/`,
  emits sha256/sha512) → `publish-rubygems` (trusted publishing via
  `rubygems/configure-rubygems-credentials`, a Sigstore bundle, skipped with a
  warning if the version is already on RubyGems) → `upload-release-assets`.
- `deploy-docs.yml` — on a published release or manual dispatch; calls
  `zoolutions/docs-kit/.github/workflows/deploy.yml@main` with
  `image: zoolutions/phlex-forms` and `service: phlex-forms`.

There is **no** workflow for the `docs/` app itself: `docs/bin/ci` (setup,
rubocop, bundler-audit, `bin/importmap audit`, brakeman) is run by hand.

## Related

- `../testing/summary.md` — what the CI jobs run
- `../docs-site/summary.md` — the app `deploy-docs.yml` ships
