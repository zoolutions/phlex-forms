# frozen_string_literal: true

source "https://rubygems.org"
gemspec

group :development, :test do
  gem "actionview", "~> 8.0" # ActionText::RichText stub for rich-text specs
  gem "activemodel", "~> 8.0" # for model-bound / validation-inference specs
  gem "async", require: false # runs conformance-kit's "fiber-safe under an Async reactor" example
  gem "conformance-kit", "~> 0.4", require: false # concurrency conformance gates (zoolutions/phlex-reactive#363)
  # soft runtime dependency (gemspec has no hard dep); present here to test
  # Forms::Live and the Forms::TagField tag primitives (>= 0.12.2 ships the
  # reactive_tags(name:)/reactive_filter(input:) escape hatches the tag widget's
  # instance-dynamic wire name needs — issue #6 Caveats 1 & 2).
  gem "phlex-reactive", ">= 0.12.2"
  gem "debug"
  gem "gem-release"
  gem "railties", "~> 8.0", require: false # boots a minimal Rails app in spec/phlex_forms/rails_boot_spec.rb
  gem "rake"
  gem "rspec"
  gem "rubocop"
  gem "rubocop-performance"
  gem "rubocop-rake"
  gem "rubocop-rspec"
  gem "rubocop-thread_safety", ">= 0.8", require: false # conformance-kit config/rubocop.yml
  gem "super_diff"
end
