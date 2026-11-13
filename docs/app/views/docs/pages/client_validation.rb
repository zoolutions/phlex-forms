# frozen_string_literal: true

# The Stimulus mirror framework: validate: true.
class Views::Docs::Pages::ClientValidation < DocsUI::Page
  title "Client-side validation"
  eyebrow "Validation"

  def lead = "validate: true mirrors your ActiveModel validators into shipped Stimulus controllers — the no-phlex-reactive fallback."

  def content
    turning_it_on
    per_field
    whats_supported
    length_counter
    messages
  end

  private

  def turning_it_on
    DocsUI::Section("Turning it on") do
      md <<~'MD'
        `validate: true` introspects the model's validators and emits
        `data-validations--*` bindings per field, plus a form-level
        submit coordinator. The form gets `novalidate` — the shipped Stimulus
        controllers own error display, so you never see the inconsistent native
        browser bubbles.
      MD
      DocsUI::Code(<<~'RUBY')
        Form(model: @partner, validate: true) do |f|
          f.field :title
          f.field :note
          f.submit :primary
        end
      RUBY
      md <<~'MD'
        Register the controllers once (see [Installation](/docs/installation)):
      MD
      DocsUI::Code(<<~'JS', filename: "app/javascript/controllers/index.js", lexer: :javascript)
        import { lazyLoadControllersFrom } from "@hotwired/stimulus-loading"
        lazyLoadControllersFrom("phlex_forms/controllers", application)
      JS
    end
  end

  def per_field
    DocsUI::Section("Per-field overrides") do
      DocsUI::Code(<<~'RUBY')
        Form(model: @partner, validate: true) do |f|
          f.field :title                                      # every validator on :title
          f.field :slug, validate: false                      # opt this field out
          f.field :note, validate: { length: { maximum: 30 } } # explicit inline rules
        end
      RUBY
    end
  end

  def whats_supported
    DocsUI::Section("What's supported") do
      md <<~'MD'
        Presence, length (with a live character counter), format, numericality,
        inclusion, exclusion, confirmation, and acceptance.

        Validators with `:if`, `:unless`, or `:on` are **skipped** — they need
        server context — and uniqueness can't be checked client-side. The
        server stays authoritative either way; this layer is UX, not
        enforcement.
      MD
      DocsUI::Callout(:tip) do
        plain "If those gaps matter, "
        a(href: "/docs/live-validation") { "live validation" }
        plain " closes all of them by running the real validators server-side."
      end
    end
  end

  def length_counter
    DocsUI::Section("Length counter", description: "A live n / limit next to the field, with an optional recommended length.") do
      md <<~'MD'
        A length rule with a `maximum:` renders a live `n / maximum` counter.
        Add `recommended:` to count against a lower, advisory length: it never
        adds an error, never becomes `maxlength`, and the server ignores it
        (ActiveModel keeps the unknown option without reading it).
      MD
      DocsUI::Code(<<~'RUBY')
        f.field :title, as: :textarea, validate: { length: { maximum: 50, recommended: 32 } }

        # or on the model; the introspector reads it the same way
        validates :title, length: { maximum: 50, recommended: 32 }
      RUBY
      DocsUI::Table(
        [ "Length", "Counter", "Class" ],
        [
          [ "up to recommended", [ :code, "n / recommended" ], "none" ],
          [ "past recommended, up to maximum", [ :code, "n / maximum" ], [ :code, "text-warning" ] ],
          [ "past maximum", [ :code, "n / maximum" ], [ :code, "text-error" ] ]
        ]
      )
      md <<~'MD'
        Past the maximum the field also shows the `too_long` message on blur and
        blocks the submit, as before. Without a `maximum:`, the counter reads
        `n / recommended` and turns `text-warning` past it. An inline `validate: { length: { recommended: 32 } }`
        needs no bound; a model-level `validates … length:` still needs one,
        because ActiveModel requires it there. A `recommended:` that is not a
        positive Integer below the maximum, or one next to an exact `is:`, is
        ignored, and the counter behaves as if it were not set.
      MD
      DocsUI::Callout(:note) do
        plain "The counter's text-warning and text-error classes are toggled from the gem's JavaScript, "
        plain "so your Tailwind build must include them. The counter comes from these client-side rules only: "
        plain "live validation's server round trip adds none, so a live field shows one only when it also "
        plain "carries client-side length rules."
      end
    end
  end

  def messages
    DocsUI::Section("Messages & i18n") do
      md <<~'MD'
        A validator's own `message:` reaches the browser, so the client shows
        the text the server would add:

        - a **String** is used as is; `%{value}` is filled in client-side, and
          `%{count}` for rules that have one (length, the numericality bounds).
        - a **Symbol** is resolved on the server through ActiveModel's lookup
          chain (`activemodel.errors.models.<model>.attributes.<attr>.<key>`,
          then `errors.messages.<key>`) in the current locale.
        - a **Proc** is skipped (it needs a record); the generic message shows.

        Length's `too_long:`, `too_short:` and `wrong_length:` win over
        `message:`, as on the server. An inline `validate: { ... }` hash takes
        the same options; a Symbol there has no model behind it, so it resolves
        through `errors.messages.<key>` only, with `%{attribute}` reading "Value".
      MD
      DocsUI::Code(<<~'RUBY')
        validates :code, format: { with: /\A[a-z]*\z/, message: "may only contain lowercase letters" }
        validates :bio, length: { maximum: 160, too_long: "keep it under %{count} characters" }
      RUBY
      md <<~'MD'
        Without a `message:`, the bundled messages apply. They ship for `en`,
        `fr`, and `af`; override any string page-wide via
        `window.PhlexForms.messages`. The engine prepends the gem's locale files
        to `I18n.load_path`, so your app's files win.
      MD
    end
  end
end
