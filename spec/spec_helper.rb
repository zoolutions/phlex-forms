# frozen_string_literal: true

require "bundler/setup"
Bundler.setup

require "i18n"
require "active_model"
require "phlex-forms"
require "conformance_kit/rspec"
require "super_diff/rspec"

# Load the gem's own locale files so I18n.t used inside components resolves in
# specs the same way it would in a host app (which prepends these via the Engine).
I18n.load_path += Dir[File.expand_path("../config/locales/*.yml", __dir__)]
I18n.available_locales = %i[en sv de]
I18n.default_locale = :en

# Forms::Live needs the reactive verifier (token signing on every render) and
# the :form_attributes param type its action schema is declared with. The
# engine does this in a host app; do it here for the live specs.
if defined?(Phlex::Reactive)
  Phlex::Reactive.verifier = ActiveSupport::MessageVerifier.new("phlex-forms-test-secret")
  Forms::Live.register_param_type!
end

Dir["./spec/support/**/*.rb"].each { |f| require f }

RSpec.configure do |config|
  config.include ComponentHelpers
  config.include HTMLHelpers
  config.include PhlexHelpers
  config.include ModelHelpers

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups

  # Reset gem configuration between examples so an icon-renderer override in one
  # spec never leaks into another.
  config.after { PhlexForms.reset_configuration! }

  config.order = :random
  Kernel.srand config.seed
end
