# frozen_string_literal: true

# Every PhlexForms.configure knob in one place.
class Views::Docs::Pages::Configuration < DocsUI::Page
  title "Configuration"
  eyebrow "Reference"

  def lead = "Four knobs on PhlexForms.configure: theme, inference, variants, and the icon renderer."

  def content
    the_block
    the_knobs
    icons
  end

  private

  def the_block
    DocsUI::Section("PhlexForms.configure") do
      DocsUI::Code(<<~'RUBY', filename: "config/initializers/phlex_forms.rb")
        PhlexForms.configure do |c|
          c.theme            = :plain          # :daisy (default), :plain, or a Theme
          c.infer_from_model = true            # the model-driven inference kill switch
          c.field_variants   = [:primary]      # global variants under every field's input
          c.icon_renderer    = PhlexForms::Configuration.glyphs_renderer
        end
      RUBY
      md <<~'MD'
        Reset with `PhlexForms.reset_configuration!` (handy in test suites).
      MD
    end
  end

  def the_knobs
    DocsUI::Section("The knobs") do
      DocsUI::Table(
        [ "Knob", "Default", "Effect" ],
        [
          [ [ :code, "theme" ], "daisy",
           "The default theme. Accepts :daisy, :plain, or a PhlexForms::Theme instance. Per-form theme: and form_options theme: override it." ],
          [ [ :code, "infer_from_model" ], "true",
           "Gates structure/column/validator inference. false restores pure attribute-name inference — the pre-inference rendering." ],
          [ [ :code, "field_variants" ], "[]",
           "daisyUI variants prepended to every field's inner input, beneath form-level and call-site variants." ],
          [ [ :code, "icon_renderer" ], "bundled inline SVG",
           "A callable ->(name, **opts) returning a renderable, used wherever the gem draws an icon." ]
        ]
      )
    end
  end

  def icons
    DocsUI::Section("Icons") do
      md <<~'MD'
        The default renderer is a bundled inline SVG, so the gem renders
        identically with no host setup. To resolve icons from your app's
        [glyphs](https://glyphs.zoolutions.llc) / rails_icons asset tree
        instead:
      MD
      DocsUI::Code(<<~'RUBY', filename: "config/initializers/phlex_forms.rb")
        PhlexForms.configure do |c|
          c.icon_renderer = PhlexForms::Configuration.glyphs_renderer
        end
      RUBY
      DocsUI::Callout(:note) do
        plain "glyphs is deliberately not the default: rails_icons reads SVGs "
        plain "from the host app's asset paths, which a minimal host has not "
        plain "set up — the inline default can never raise."
      end
    end
  end
end
