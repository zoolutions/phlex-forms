# frozen_string_literal: true

require "open3"
require "rbconfig"

# Without Rails, configure finalizes when its block returns, which builds the
# themes (and, with phlex-reactive bundled, loads its components). Runs in a
# child process, so nothing this suite has already loaded (json included) hides
# a missing require.
RSpec.describe "phlex-forms booted without Rails" do
  let(:script) do
    <<~RUBY
      abort "json already loaded" if defined?(JSON)
      require "phlex-forms"
      abort "Rails loaded" if defined?(Rails::Engine)

      PhlexForms.configure do |c|
        c.field_variants = [:sm]
        c.icon_renderer = ->(name, **) { "<i>\#{name}</i>" }
      end
      config = PhlexForms.config
      puts [config.frozen?, Ractor.shareable?(config.theme), config.render_icon(:x)].inspect
    RUBY
  end

  it "finalizes in configure, keeping an unshareable renderer working" do
    lib = File.expand_path("../../lib", __dir__)
    output, status = Open3.capture2e(RbConfig.ruby, "-rbundler/setup", "-I#{lib}", "-e", script)

    expect(status).to be_success, output
    expect(output.lines.last.chomp).to eq('[true, true, "<i>x</i>"]')
  end
end
