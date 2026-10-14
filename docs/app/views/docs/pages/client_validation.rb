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

  def messages
    DocsUI::Section("Messages & i18n") do
      md <<~'MD'
        A validator's own `message:` reaches the browser, so the client shows
        the text the server would add:

        - a **String** is used as is; `%{count}` is filled in client-side.
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
