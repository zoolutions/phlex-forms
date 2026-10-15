# frozen_string_literal: true

require "open3"
require "rbconfig"

# phlex-reactive is a soft dependency: the gem must boot and resolve both themes
# without it. Run in a child process, where `require "phlex/reactive"` fails.
RSpec.describe "phlex-forms without phlex-reactive" do
  let(:script) do
    <<~RUBY
      require "phlex-forms"
      abort "phlex-reactive was loaded" if defined?(Phlex::Reactive)

      roles = [PhlexForms::Theme.daisy[:input], PhlexForms::Theme.plain[:input]]
      begin
        PhlexForms::Theme.daisy[:tag_field]
      rescue KeyError
        roles << :no_tag_field
      end
      puts roles.inspect
    RUBY
  end

  it "builds both themes, without the reactive roles" do
    preload = File.expand_path("../fixtures/without_phlex_reactive.rb", __dir__)
    lib = File.expand_path("../../lib", __dir__)
    output, status = Open3.capture2e(RbConfig.ruby, "-rbundler/setup", "-r#{preload}", "-I#{lib}", "-e", script)

    expect(status).to be_success, output
    expect(output.lines.last.chomp).to eq("[Forms::Input, Forms::Plain::Input, :no_tag_field]")
  end
end
