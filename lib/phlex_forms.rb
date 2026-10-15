# frozen_string_literal: true

require "date" # Phlex's attribute serializer references Date; ensure it's loaded.
require "active_support/core_ext/object/blank" # blank?/present?/presence
require "active_support/core_ext/enumerable" # exclude?
require "active_support/core_ext/string" # underscore/pluralize/humanize (scope/url/label derivation)
require "phlex"
require "glyphs"
require "zeitwerk"
require "daisy_ui"

begin
  # phlex-reactive's Sortable calls Hash#to_json while it loads without
  # requiring json (a Rails host has it loaded already). Finalizing builds the
  # themes, which load the tag-field leaves and with them Sortable, so without
  # Rails `configure` would raise NoMethodError.
  require "json"
  require "phlex/reactive"
rescue LoadError
  # phlex-reactive is a soft dependency: without it the `live` server-truth
  # validation macro raises a FeatureUnavailable pointing here, and the live
  # files are excluded from autoloading below (they include
  # Phlex::Reactive::Component at class level, so they must not load).
end

require_relative "phlex_forms/version"

# phlex-forms exposes its components under the `Forms::` namespace (Form, Input,
# Select, Submit, Label, ...) so that consuming apps can `include Forms` and call
# `Form(model:) { |f| ... }` as a Phlex::Kit helper. Gem-internal machinery
# (configuration, the icon renderer) lives under `PhlexForms::` to keep the
# `Forms::` namespace clean for components only.
module PhlexForms
  class Error < StandardError; end

  # Raised when an optional feature (e.g. rich text via ActionText/Lexxy) is
  # used but its backing dependency is not available.
  class FeatureUnavailable < Error; end

  # @configuration is built when this file loads (see the bottom) and replaced
  # only by configure and reset_configuration!, on the main Ractor at boot or
  # between tests (a non-main Ractor cannot write a module ivar). Once finalized
  # it is frozen and Ractor-shareable, so any Ractor may read it.
  # rubocop:disable-next ThreadSafety/ClassInstanceVariable
  class << self
    attr_reader :configuration
    alias config configuration

    # Yields the configuration, then finalizes it unless the Rails engine is
    # loaded (its after_initialize finalizes once every initializer has run). A
    # finalized configuration is never edited in place: the block gets a copy,
    # which is finalized and swapped in whole.
    def configure
      if @configuration.frozen?
        draft = @configuration.dup
        yield(draft)
        @configuration = draft.finalize!
      else
        yield(@configuration)
        finalize! unless defined?(PhlexForms::Engine)
      end
    end

    # Freezes the configuration with Ractor-shareable settings (see
    # Configuration#finalize!). Idempotent; returns the configuration.
    def finalize!
      @configuration.finalize!
    end

    # Reset configuration to defaults, open again. Intended for test isolation.
    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end

# The component namespace. Extending Phlex::Kit makes every `Forms::Foo`
# component callable as a bare `Foo(...)` helper wherever `Forms` is included.
module Forms
  extend Phlex::Kit
end

# Two non-overlapping autoload roots:
#   lib/phlex_forms/**        (minus components) -> PhlexForms::  (gem internals)
#   lib/phlex_forms/components -> Forms::                          (components)
# We drive the loader manually (not `for_gem`) so the component root can map
# onto the top-level `Forms` module while gem internals stay under `PhlexForms`.
loader = Zeitwerk::Loader.new
loader.tag = "phlex-forms"
loader.inflector.inflect(
  "phlex_forms" => "PhlexForms",
  "phlex-forms" => "PhlexForms"
)

# Two sibling (non-nested) autoload roots:
#   lib/phlex_forms -> PhlexForms::  (gem internals: config, inference, theme, ...)
#   lib/forms       -> Forms::        (the component kit)
# Keeping them as separate top-level dirs avoids the ambiguity of nesting one
# namespace root inside another.
loader.push_dir("#{__dir__}/phlex_forms", namespace: PhlexForms)
loader.push_dir("#{__dir__}/forms", namespace: Forms)

# Files required explicitly above, or loaded only in specific contexts.
loader.ignore("#{__dir__}/phlex_forms/version.rb") # required explicitly above
loader.ignore("#{__dir__}/rubocop") # cops load on demand via the host .rubocop.yml
loader.ignore("#{__dir__}/phlex_forms/rubocop.rb") # cop entry point (RuboCop:: namespace)
# The engine is conditionally required at the bottom of this file (only under
# Rails), so it must not be autoloaded/eager-loaded by Zeitwerk.
loader.ignore("#{__dir__}/phlex_forms/engine.rb")

# The live-validation layer includes Phlex::Reactive::Component at class level,
# and the tag_field leaf includes Phlex::Reactive::ClientBindings — both can only
# load when the phlex-reactive soft dependency is present.
unless defined?(Phlex::Reactive)
  loader.ignore("#{__dir__}/forms/live.rb")
  loader.ignore("#{__dir__}/forms/live")
  loader.ignore("#{__dir__}/forms/tag_field.rb")
  loader.ignore("#{__dir__}/forms/plain/tag_field.rb")
  loader.ignore("#{__dir__}/forms/rootless_tag_field.rb")
  loader.ignore("#{__dir__}/forms/plain/rootless_tag_field.rb")
end

loader.setup

# The default configuration, built at load (never lazily, so no two readers
# race to create it).
PhlexForms.reset_configuration!

# Optional Rails integration (Stimulus controllers via importmap/assets, and
# the gem's default locale files). Loaded only under Rails; the gem stays pure
# Phlex otherwise.
require_relative "phlex_forms/engine" if defined?(Rails::Engine)
