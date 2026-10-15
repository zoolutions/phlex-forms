# frozen_string_literal: true

# Tier 3 of conformance-kit: after boot every theme and configuration reader
# returns a Ractor-shareable value, so a non-main Ractor can read them.
RSpec.describe "PhlexForms.finalize!" do
  def self.readers
    {
      "PhlexForms::Theme.daisy" => -> { PhlexForms::Theme.daisy },
      "PhlexForms::Theme.plain" => -> { PhlexForms::Theme.plain },
      "PhlexForms.configuration" => -> { PhlexForms.configuration },
      "PhlexForms.configuration.theme" => -> { PhlexForms.configuration.theme },
      "PhlexForms.configuration.infer_from_model" => -> { PhlexForms.configuration.infer_from_model },
      "PhlexForms.configuration.field_variants" => -> { PhlexForms.configuration.field_variants },
      "PhlexForms.configuration.icon_renderer" => -> { PhlexForms.configuration.icon_renderer }
    }
  end

  context "with the defaults" do
    it_behaves_like "a boot-finalized configuration", readers:, finalize: -> { PhlexForms.finalize! }
  end

  context "with every knob set through configure" do
    it_behaves_like "a boot-finalized configuration", readers:, finalize: lambda {
      PhlexForms.configure do |c|
        c.theme = PhlexForms::Theme.plain.with(input: Forms::Input)
        c.infer_from_model = false
        c.field_variants = [:primary]
        c.icon_renderer = PhlexForms::Configuration.glyphs_renderer
      end
    }
  end

  it "builds each theme once" do
    expect(PhlexForms::Theme.daisy).to equal(PhlexForms::Theme.daisy)
    expect(PhlexForms::Theme.plain).to equal(PhlexForms::Theme.resolve(:plain))
  end

  it "returns the finalized configuration, every time" do
    expect(PhlexForms.finalize!).to be_frozen.and equal(PhlexForms.finalize!)
  end

  it "leaves the configuration open until it is finalized" do
    PhlexForms.config.infer_from_model = false

    expect(PhlexForms.config.infer_from_model).to be(false)
    expect(PhlexForms.config).not_to be_frozen
  end

  it "rejects a direct write once finalized" do
    PhlexForms.finalize!

    expect { PhlexForms.config.infer_from_model = false }.to raise_error(FrozenError)
  end

  describe ".configure" do
    it "finalizes the configuration when the Rails engine is absent" do
      PhlexForms.configure { |c| c.field_variants = [:sm] }

      expect(PhlexForms.config).to be_frozen
      expect(PhlexForms.config.field_variants).to eq([:sm])
    end

    it "leaves finalizing to the engine's after_initialize under Rails" do
      stub_const("PhlexForms::Engine", Class.new)

      PhlexForms.configure { |c| c.field_variants = [:sm] }

      expect(PhlexForms.config).not_to be_frozen
    end

    it "edits a copy of a finalized configuration and keeps its earlier settings" do
      PhlexForms.configure { |c| c.theme = :plain }
      before = PhlexForms.config

      PhlexForms.configure { |c| c.field_variants << :sm }

      expect(PhlexForms.config).not_to equal(before)
      expect(PhlexForms.config).to be_frozen
      expect(PhlexForms.config.theme).to eq(:plain)
      expect(PhlexForms.config.field_variants).to eq([:sm])
      expect(before.field_variants).to eq([])
    end

    it "returns the block's value, open or finalized" do
      expect(PhlexForms.configure { :first }).to eq(:first)
      expect(PhlexForms.configure { :again }).to eq(:again)
    end

    it "keeps field_variants appendable after it is set to nil" do
      PhlexForms.configure { |c| c.field_variants = nil }

      PhlexForms.configure { |c| c.field_variants << :sm }

      expect(PhlexForms.config.field_variants).to eq([:sm])
    end

    it "never freezes the caller's own objects" do
      variants = [:primary]

      PhlexForms.configure { |c| c.field_variants = variants }

      expect(variants).not_to be_frozen
      expect(PhlexForms.config.field_variants).to eq([:primary])
    end

    it "keeps a renderer that cannot be shared working on the main Ractor" do
      PhlexForms.configure { |c| c.icon_renderer = ->(name, **) { "<i>#{name}</i>" } }

      expect(PhlexForms.config).to be_frozen
      expect(PhlexForms.config.render_icon(:x)).to eq("<i>x</i>")
    end

    it "keeps a renderer object that holds its own state, unfrozen" do
      renderer = Class.new do
        def initialize = @rendered = []
        def call(name, **) = (@rendered << name) && "<i>#{name}</i>"
      end.new

      PhlexForms.configure { |c| c.icon_renderer = renderer }

      expect(PhlexForms.config).to be_frozen
      expect(PhlexForms.config.icon_renderer).to equal(renderer)
      expect(PhlexForms.config.render_icon(:x)).to eq("<i>x</i>")
      expect(renderer).not_to be_frozen
    end
  end

  describe ".reset_configuration!" do
    it "restores the defaults, open again" do
      PhlexForms.configure { |c| c.theme = :plain }

      PhlexForms.reset_configuration!

      expect(PhlexForms.config).not_to be_frozen
      expect(PhlexForms.config.theme).to equal(PhlexForms::Theme.daisy)
      expect(PhlexForms.config.render_icon("chevron-down")).to include("<svg")
    end
  end
end
