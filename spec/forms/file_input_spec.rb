# frozen_string_literal: true

require "spec_helper"

# Rails' file_field appends [] to the input name when multiple is set; without
# it the browser collapses a multi-file selection into ONE scalar param, which
# a host app's `params.expect(attr: [])` silently discards — uploads no-op
# with a success response (cosmos production, Aug 2026).
describe Forms::FileInput do
  it "keeps the plain name for single-file inputs" do
    output = render_component(described_class.new(name: "user[avatar]"))

    expect(output).to include('name="user[avatar]"')
    expect(output).not_to include("multiple")
  end

  it "appends [] to the name when multiple (Rails file_field parity)" do
    output = render_component(described_class.new(name: "retreat[gallery]", multiple: true))

    expect(output).to include('name="retreat[gallery][]"')
    expect(output).to include("multiple")
  end

  it "does not double-append when the caller already passed []" do
    output = render_component(described_class.new(name: "retreat[gallery][]", multiple: true))

    expect(output).to include('name="retreat[gallery][]"')
    expect(output).not_to include("[][]")
  end

  it "appends [] through the form builder too" do
    user = build_model(:user, name: "Ada")
    output = PhlexHelpers::FormContext.new(
      model: user, form_args: {},
      form_block: ->(f) { f.FileInput(:name, multiple: true) }
    ).call

    expect(output).to include('name="user[name][]"')
  end

  it "applies the same normalization to the Plain variant" do
    output = render_component(Forms::Plain::FileInput.new(name: "retreat[gallery]", multiple: true))

    expect(output).to include('name="retreat[gallery][]"')
  end
end
