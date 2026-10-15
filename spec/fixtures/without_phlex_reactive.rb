# frozen_string_literal: true

# Preloaded (`ruby -r`) by spec/phlex_forms/soft_dependency_spec.rb, after
# bundler/setup: drops phlex-reactive from the load path, so
# `require "phlex/reactive"` raises LoadError as in a host that does not bundle
# the soft dependency.
reactive = Gem.loaded_specs.fetch("phlex-reactive")
$LOAD_PATH.reject! { |path| reactive.full_require_paths.include?(path) }
