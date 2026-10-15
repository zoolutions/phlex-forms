# frozen_string_literal: true

module PhlexForms
  # Optional Rails integration. Loaded only when Rails::Engine is defined (see
  # lib/phlex_forms.rb), so the gem stays a plain Phlex library outside Rails.
  #
  # It wires up:
  #   * the bundled Stimulus controllers (choices / searchable-select / tz) via
  #     importmap-rails + the asset load path;
  #   * the gem's default locale files (en/sv/de) prepended to I18n.load_path so
  #     host apps can override any key.
  #
  # Asset-and-locale-only engine: no isolate_namespace, since it exposes no
  # routes, models, or helpers.
  class Engine < ::Rails::Engine
    JAVASCRIPT_PATH = root.join("app/javascript")

    initializer "phlex_forms.assets" do |app|
      app.config.assets.paths << JAVASCRIPT_PATH.to_s if app.config.respond_to?(:assets)
    end

    initializer "phlex_forms.importmap", before: "importmap" do |app|
      next unless app.config.respond_to?(:importmap)

      importmap = app.config.importmap
      importmap.paths << root.join("config/importmap.rb") if importmap.respond_to?(:paths)
      importmap.cache_sweepers << JAVASCRIPT_PATH if importmap.respond_to?(:cache_sweepers)
    end

    initializer "phlex_forms.i18n" do |app|
      locales = Dir[root.join("config/locales/*.yml")].map(&:to_s)
      app.config.i18n.load_path.unshift(*locales)
    end

    # PhlexForms.configure leaves the configuration open under Rails; freeze it
    # (with Ractor-shareable settings) once every initializer has run.
    config.after_initialize { PhlexForms.finalize! }

    # The raw-hash param type Forms::Live's :validate action schema declares.
    # Registered from an initializer because phlex-reactive freezes its
    # param-type registry after boot.
    initializer "phlex_forms.live_param_type" do
      Forms::Live.register_param_type! if defined?(Phlex::Reactive)
    end
  end
end
