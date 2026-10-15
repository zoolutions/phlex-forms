# frozen_string_literal: true

# Run by spec/phlex_forms/rails_boot_spec.rb in a child process: boots a minimal
# Rails app rooted at ARGV[0] (whose config/initializers/ the spec writes), the
# way a host app boots, then writes what the booted configuration looks like to
# booted.json in that root. Loads phlex-forms after Rails, as Bundler.require
# does, so the engine loads too.
require "json"
require "logger"
require "rails"
require "action_controller/railtie"
require "phlex-forms"

class BootApp < Rails::Application
  config.root = ARGV.fetch(0)
  config.eager_load = false
  config.logger = Logger.new(IO::NULL)
  config.secret_key_base = "phlex-forms-rails-boot-spec"
end

BootApp.initialize!

config = PhlexForms.config
File.write(File.join(ARGV.fetch(0), "booted.json"), JSON.generate(
  engine: !defined?(PhlexForms::Engine).nil?,
  frozen: config.frozen?,
  shareable: Ractor.shareable?(config),
  theme_shareable: Ractor.shareable?(config.theme),
  field_variants: config.field_variants,
  field_variants_shareable: Ractor.shareable?(config.field_variants),
  infer_from_model: config.infer_from_model,
  icon_renderer_shareable: Ractor.shareable?(config.icon_renderer),
  icon: config.render_icon("chevron-down").to_s[0, 40]
))
