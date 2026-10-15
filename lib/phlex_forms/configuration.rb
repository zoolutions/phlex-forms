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
  #
  # Finalized at boot: `configure` finalizes when the Rails engine is absent, the
  # engine's after_initialize does under Rails (or call `PhlexForms.finalize!`).
  # Finalizing freezes the configuration and stores Ractor-shareable copies of
  # its settings, so any Ractor can read it. A renderer that cannot be shared (a
  # lambda written at the top level of an initializer has `main` as its self) is
  # kept as given and still works on the main Ractor; build it in a class or
  # module body, or with `Ractor.shareable_lambda` on Ruby 4.0, to keep the
  # whole configuration shareable. A renderer that is not a Proc (an object with
  # #call, a Method) is never copied or frozen: it is shared only if it already
  # is. After finalizing, write through `configure`, which edits a copy and
  # swaps it in.
  class Configuration
    # The bundled inline SVGs. Built in the class body (self is the class and the
    # lambda captures nothing), so it can be made shareable once, here.
    DEFAULT_ICON_RENDERER = Shareable.copy(->(name, **opts) { InlineIcons.render(name, **opts) })

    # A ready-made renderer that delegates to glyphs' LucideIcon. Raises a clear
    # error if glyphs is not loaded.
    def self.glyphs_renderer
      unless defined?(Glyphs::LucideIcon)
        raise PhlexForms::FeatureUnavailable,
          "PhlexForms glyphs_renderer requires the `glyphs` gem to be loaded"
      end

      Shareable.copy(->(name, **opts) { Glyphs::LucideIcon.new(name, **opts) })
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

    # The default theme: :daisy, :plain, or a PhlexForms::Theme instance.
    # Defaults to daisy.
    attr_writer :theme

    # Every default is set here, never memoized by a reader, so concurrent
    # readers never race to build one. The theme stays nil until set or
    # finalized (the reader falls back to Theme.daisy), so building a
    # configuration loads no component.
    def initialize
      @theme = nil
      @infer_from_model = true
      @field_variants = []
      @icon_renderer = DEFAULT_ICON_RENDERER
    end

    # `configure` on a finalized configuration edits a copy: give the copy its
    # own variants list, so `c.field_variants << :sm` works on it.
    def initialize_copy(source)
      super
      @field_variants = @field_variants.dup
    end

    def field_variants
      @field_variants || []
    end

    def theme
      @theme || Theme.daisy
    end

    def infer_from_model
      @infer_from_model.nil? || @infer_from_model
    end

    def icon_renderer
      @icon_renderer || DEFAULT_ICON_RENDERER
    end

    # Returns a renderable for the named icon. Components pass the result to Phlex
    # `render`/`raw` as appropriate.
    def render_icon(name, **)
      icon_renderer.call(name.to_s, **)
    end

    # Stores Ractor-shareable copies of every setting and freezes the
    # configuration. Resolves the default theme, which builds both built-in
    # themes at boot rather than on the first render. Idempotent; returns self.
    def finalize!
      return self if frozen?

      @theme = Shareable.copy(theme)
      @infer_from_model = Shareable.copy(@infer_from_model)
      @field_variants = Shareable.copy(@field_variants)
      @icon_renderer = Shareable.callable(@icon_renderer)
      freeze
    end
  end
end
