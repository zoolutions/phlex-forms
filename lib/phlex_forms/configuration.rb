# frozen_string_literal: true

module PhlexForms
  # Central configuration for phlex-forms. Set via `PhlexForms.configure`.
  #
  #   PhlexForms.configure do |c|
  #     c.icon_renderer = ->(name, **opts) { MyIcons::Icon.new(name, **opts) }
  #   end
  #
  # The icon renderer is a callable `->(name, **opts) { renderable }` returning
  # something a Phlex component can emit: a Phlex component instance OR a raw SVG
  # String.
  #
  # The DEFAULT is a bundled inline SVG so phlex-forms is self-contained and
  # renders identically with no host configuration. To use the glyphs gem (which
  # resolves a full icon set from the host app's rails_icons asset tree), opt in:
  #
  #   PhlexForms.configure do |c|
  #     c.icon_renderer = PhlexForms::Configuration.glyphs_renderer
  #   end
  #
  # glyphs is intentionally NOT the default: rails_icons reads SVGs from the host
  # app's asset paths, which a minimal host (or the gem's own test suite) has not
  # set up — so defaulting to glyphs would raise Icons::IconNotFound.
  class Configuration
    # A ready-made renderer that delegates to glyphs' LucideIcon. Raises a clear
    # error if glyphs is not loaded.
    def self.glyphs_renderer
      unless defined?(Glyphs::LucideIcon)
        raise PhlexForms::FeatureUnavailable,
          "PhlexForms glyphs_renderer requires the `glyphs` gem to be loaded"
      end

      ->(name, **opts) { Glyphs::LucideIcon.new(name, **opts) }
    end

    attr_writer :icon_renderer

    # Kill-switch for model-driven inference (columns/enums/associations/
    # validator attributes). Defaults to on; set false to restore pure
    # attribute-name inference for `field`.
    attr_writer :infer_from_model

    # Global daisyui variants prepended to every `field`'s inner input, e.g.
    # `c.field_variants = [:primary]`. Form-level `field_variants:` and
    # call-site modifiers stack after (later wins).
    attr_writer :field_variants

    def field_variants
      @field_variants ||= []
    end

    # The default theme: :daisy, :plain, or a PhlexForms::Theme instance.
    # Defaults to daisy.
    attr_writer :theme

    def theme
      @theme ||= Theme.daisy
    end

    def infer_from_model
      return @infer_from_model if defined?(@infer_from_model) && !@infer_from_model.nil?

      true
    end

    def icon_renderer
      @icon_renderer ||= ->(name, **opts) { InlineIcons.render(name, **opts) }
    end

    # Returns a renderable for the named icon. Components pass the result to Phlex
    # `render`/`raw` as appropriate.
    def render_icon(name, **)
      icon_renderer.call(name.to_s, **)
    end
  end
end
