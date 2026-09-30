# frozen_string_literal: true

source "https://rubygems.org"
gemspec

group :development, :test do
  gem "actionview", "~> 8.0" # ActionText::RichText stub for rich-text specs
  gem "activemodel", "~> 8.0" # for model-bound / validation-inference specs
  # soft runtime dependency (gemspec has no hard dep); present here to test
  # Forms::Live and the Forms::TagField tag primitives (>= 0.12.2 ships the
  # reactive_tags(name:)/reactive_filter(input:) escape hatches the tag widget's
  # instance-dynamic wire name needs — issue #6 Caveats 1 & 2).
  gem "phlex-reactive", ">= 0.12.2"
  gem "debug"
  gem "gem-release"
  gem "rake"
  gem "rspec"
  gem "rubocop"
  gem "rubocop-performance"
  gem "rubocop-rake"
  gem "rubocop-rspec"
  gem "super_diff"
end
