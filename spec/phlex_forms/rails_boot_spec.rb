# frozen_string_literal: true

require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "tmpdir"

# Under Rails the engine finalizes the configuration in after_initialize, with
# no app code. Each example boots a minimal Rails app in a child process, so the
# engine never loads into this suite (where configure finalizes by itself
# because the engine is absent).
RSpec.describe "phlex-forms in a booted Rails app" do
  def boot(initializer = nil)
    Dir.mktmpdir do |root|
      if initializer
        FileUtils.mkdir_p(File.join(root, "config/initializers"))
        File.write(File.join(root, "config/initializers/phlex_forms.rb"), initializer)
      end
      script = File.expand_path("../fixtures/rails_boot.rb", __dir__)
      lib = File.expand_path("../../lib", __dir__)
      output, status = Open3.capture2e(RbConfig.ruby, "-rbundler/setup", "-I#{lib}", script, root)

      expect(status).to be_success, output
      JSON.parse(File.read(File.join(root, "booted.json")), symbolize_names: true)
    end
  end

  it "finalizes the default configuration, shareable, with no app code" do
    booted = boot

    expect(booted).to include(engine: true, frozen: true, shareable: true, icon_renderer_shareable: true)
    expect(booted[:icon]).to start_with("<svg")
  end

  it "finalizes what the initializers wrote, direct writes included" do
    booted = boot(<<~RUBY)
      PhlexForms.configure { |c| c.field_variants = [:sm] }
      PhlexForms.config.infer_from_model = false
    RUBY

    expect(booted).to include(frozen: true, shareable: true, field_variants: ["sm"],
      field_variants_shareable: true, infer_from_model: false)
  end

  it "boots with an icon renderer that cannot be shared, and keeps it working" do
    booted = boot(<<~RUBY)
      icon_log = Logger.new(IO::NULL)
      PhlexForms.configure do |c|
        c.icon_renderer = ->(name, **) { icon_log.info(name) && "<i>\#{name}</i>" }
      end
    RUBY

    expect(booted).to include(frozen: true, theme_shareable: true, field_variants_shareable: true,
      icon_renderer_shareable: false, shareable: false, icon: "<i>chevron-down</i>")
  end
end
