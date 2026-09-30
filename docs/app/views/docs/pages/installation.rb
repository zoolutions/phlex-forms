# frozen_string_literal: true

# Getting phlex-forms into an app: the gem, the kit include, and the optional
# companions (phlex-reactive, Stimulus controllers).
class Views::Docs::Pages::Installation < DocsUI::Page
  title "Installation"
  eyebrow "Getting started"

  def lead = "Add the gem, include the kit, and pick your optional companion."

  def content
    add_the_gem
    include_the_kit
    soft_dependencies
    stimulus_setup
  end

  private

  def add_the_gem
    DocsUI::Section("Add the gem", description: "In your app's Gemfile.") do
      DocsUI::Code(<<~'RUBY', filename: "Gemfile")
        gem "phlex-forms"
        gem "phlex-reactive" # optional — `live` server-truth validation
      RUBY
      md <<~'MD'
        Hard dependencies are `phlex ~> 2.0`, `daisyui ~> 2.0`,
        `activesupport`, `zeitwerk`, and `glyphs`. The daisy theme is the
        default; switch to the [Plain theme](/docs/theming) for unstyled
        semantic HTML. `phlex-reactive` is **soft**: it only gates the
        [`live` macro](/docs/live-validation).
      MD
    end
  end

  def include_the_kit
    DocsUI::Section("Include the kit") do
      md <<~'MD'
        phlex-forms exposes its components under the `Forms::` namespace as a
        [Phlex::Kit](https://www.phlex.fun/kits.html). Include it wherever you
        render components — typically your base component:
      MD
      DocsUI::Code(<<~'RUBY', filename: "app/components/application_component.rb")
        class ApplicationComponent < Phlex::HTML
          include Forms
        end
      RUBY
      md <<~'MD'
        Now `Form(...)`, `Submit(...)`, and every other `Forms::*` component are
        available as bare kit helpers, and `Forms::Base` is ready to subclass.
      MD
    end
  end

  def soft_dependencies
    DocsUI::Section("Under Rails") do
      md <<~'MD'
        The gem ships an optional Rails engine (loaded only when `Rails::Engine`
        is defined) that wires up:

        - the bundled Stimulus controllers via importmap + the asset load path,
        - the default locale files (`en`/`sv`/`de`), prepended to
          `I18n.load_path` so your app overrides any key,
        - the phlex-reactive param type the `live` action schema needs.

        Outside Rails, phlex-forms stays a plain Phlex library — the engine
        never loads.
      MD
    end
  end

  def stimulus_setup
    DocsUI::Section("Stimulus controllers (optional)") do
      md <<~'MD'
        Only needed for [client-side validation](/docs/client-validation)
        (`validate: true`) and `searchable: true` selects:
      MD
      DocsUI::Code(<<~'JS', filename: "app/javascript/controllers/index.js", lexer: :javascript)
        import { lazyLoadControllersFrom } from "@hotwired/stimulus-loading"
        lazyLoadControllersFrom("phlex_forms/controllers", application)
      JS
      DocsUI::Callout(:note) do
        plain "JS peer dependencies: "
        code { "@hotwired/stimulus" }
        plain " for the validation controllers, and "
        code { "choices.js" }
        plain " only if you use searchable/multi selects."
      end
    end
  end
end
