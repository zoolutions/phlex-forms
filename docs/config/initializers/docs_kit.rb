# frozen_string_literal: true

# docs-kit synced: v1.0.8

# docs-kit configuration — everything that makes this site look like
# "phlex-forms" rather than any other docs site. The shared chrome
# (Shell/Sidebar/ThemeSwitcher/Code/Page) comes from the gem; only this config
# differs per site. The `themes` MUST match the @plugin "daisyui" { themes: ... }
# block in app/assets/stylesheets/application.tailwind.css.
Rails.application.config.to_prepare do
  DocsKit.configure do |c|
    c.brand        = "phlex-forms"
    c.title_suffix = "phlex-forms"

    # The one-line summary agents read first in /llms.txt (the llmstxt.org
    # blockquote under the H1).
    c.tagline = "A model-bound form builder for Phlex — forms as first-class " \
                "classes, field types inferred from the model, daisyUI or plain " \
                "semantic HTML via themes, and server-truth live validation " \
                "over phlex-reactive."

    c.themes = %w[dark light synthwave retro cyberpunk dracula night nord sunset]

    # The version badge in the sidebar header tracks the documented gem. A lambda
    # (not a String) so it re-reads PhlexForms::VERSION on every reload — the
    # phlex-forms path-gem is required as "phlex_forms/version" (Gemfile), so only
    # the constant loads; the gem's runtime deps never boot inside the docs app.
    c.version_badge = -> { "v#{PhlexForms::VERSION}" }

    # Code blocks: a light base with a dark override, so the highlight stays
    # readable when the switcher lands on a dark daisyUI theme. CSS-only scoping
    # ([data-theme=X]) — no JS, no flash.
    c.code_theme      = "Rouge::Themes::Github"  # light themes
    c.code_theme_dark = "Rouge::Themes::Monokai" # dark themes

    # A link to the source repo + the gem, rendered with shipped brand marks.
    c.topbar_links = [
      { href: "https://github.com/zoolutions/phlex-forms", label: "GitHub", icon: :github },
      { href: "https://rubygems.org/gems/phlex-forms", label: "RubyGems", icon: :rubygems }
    ]

    # SEO + social sharing. docs-kit emits the full <head> (description, Open
    # Graph, Twitter Card, canonical, favicon, theme-color) from these knobs.
    c.seo.description  = "phlex-forms is a model-bound form builder for Phlex: " \
                         "field :email renders label + input + error in one " \
                         "call with the type inferred from the model. Declarative " \
                         "form classes, daisyUI or unstyled themes, client-side " \
                         "validation, and live server-truth validation via " \
                         "phlex-reactive."
    c.seo.site_url     = "https://phlex-forms.zoolutions.llc"
    # The social-share card is generated from the landing page — run
    # `bin/rails docs_kit:og` (needs a headless browser), which writes
    # app/assets/images/og/og.png.
    c.seo.og_image     = "og/og.png"
    c.seo.og_type      = "website"
    c.seo.twitter_card = "summary_large_image"
    c.seo.twitter_site = "@mhenrixon"
    c.seo.locale       = "en_US"
    c.seo.theme_color  = "#1d232a" # daisyUI dark base-100 (themes.first)
    c.seo.favicon      = "/favicon.svg"

    # The landing page (app/views/landings/show.rb renders DocsUI::Landing) — a
    # marketing hero + feature grid + a registry-grouped doc index, all from these
    # knobs. Wrap a run in **double asterisks** to accent it in the primary color.
    c.landing.eyebrow = "Phlex form builder"
    c.landing.title   = "Forms that already know your **model**"
    c.landing.lead    = "phlex-forms renders label, input, and error in one " \
                        "field call — type, requiredness, and choices inferred " \
                        "from the model. Declare forms as Phlex classes, theme " \
                        "them daisyUI or plain, and validate live against the " \
                        "real validators."
    c.landing.install = { code: 'gem "phlex-forms"', filename: "Gemfile", lexer: :ruby }
    c.landing.ctas = [
      { label: "Get started", href: "/docs/overview", style: :primary },
      { label: "GitHub", href: "https://github.com/zoolutions/phlex-forms", style: :ghost, icon: :github }
    ]
    c.landing.features = [
      { icon: "wand-sparkles", title: "Model-driven inference",
        body: "field :notify renders a toggle for a boolean column, an enum " \
              "becomes a humanized select, a belongs_to a collection select — " \
              "as:/choices: are overrides, not requirements." },
      { icon: "blocks", title: "Forms as classes",
        body: "Subclass Forms::Base and declare fields where self IS the form — " \
              "reusable, testable form objects with inherited defaults, no f. " \
              "prefix on every line." },
      { icon: "zap", title: "Live server-truth validation",
        body: "live model: User runs your REAL validators on blur — uniqueness, " \
              ":if/:unless, confirmation — and morphs errors back with focus " \
              "preserved, via phlex-reactive." },
      { icon: "palette", title: "daisyUI or plain",
        body: "Variants stack positionally (field :email, :primary, :sm) with " \
              "form-level defaults; swap the theme and the same form class " \
              "renders bare semantic HTML in a non-daisyUI project." },
      { icon: "shield-check", title: "Client-side fallback",
        body: "No phlex-reactive? validate: true mirrors your ActiveModel " \
              "validators into shipped Stimulus controllers — presence, length " \
              "counters, format, confirmation, and more." },
      { icon: "check-check", title: "Migration-ready",
        body: "Rails-parity helpers (fields_for, collection_check_boxes), " \
              "unscoped and JSONB modes for dynamic rows, and RuboCop cops that " \
              "autocorrect legacy form calls." }
    ]

    # The sidebar nav derives from the registry — one heading → one registry.
    # Each registry's authored pages become NavItems automatically (an unwritten
    # page is skipped, so no dead links); the page `group:` values render as the
    # collapsible sub-groups. This also feeds the AI surfaces (/llms.txt,
    # /llms-full.txt, search, MCP) with zero extra code.
    c.nav_registries = { "Docs" => Doc }
  end
end
