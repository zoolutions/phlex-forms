# frozen_string_literal: true

require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = "spec/**/*_spec.rb"
end

require "rubocop/rake_task"

RuboCop::RakeTask.new

desc "Build gem and verify contents"
task :build do
  sh("gem build phlex-forms.gemspec --strict")
  gem_file = Dir["phlex-forms-*.gem"].first
  abort "Gem file not found after build" unless gem_file

  sh("gem unpack #{gem_file} --target /tmp/phlex-forms-verify")
  puts "\n=== Gem contents ==="
  sh("find /tmp/phlex-forms-verify -type f | sort")
  sh("rm -rf /tmp/phlex-forms-verify #{gem_file}")
end

# `rake release[X.Y.Z]` lives in rakelib/release.rake (the zoolutions release
# kit, see docs-kit's RELEASE_KIT.md); `bin/release` is its interactive front door.

task default: %i[spec rubocop]
