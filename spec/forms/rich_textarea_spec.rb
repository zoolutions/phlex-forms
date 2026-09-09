# frozen_string_literal: true

require "spec_helper"

# Lexxy configures an editor through child elements of `<lexxy-editor>` —
# `<lexxy-prompt>` for @mentions, `<lexxy-code-language-picker>` for code
# blocks. The component rendered the element with no block and the builder
# never forwarded one, so `f.rich_textarea(:content) { ... }` silently dropped
# its content: a host could wire mentions and get an editor that never prompts
# (cosmos, Sept 2026 — its mention endpoint 500'd for months unnoticed because
# nothing ever called it).
describe Forms::RichTextarea do
  # A host component: it registers Lexxy's child element and renders the editor
  # with a block that emits it — the real shape of a configured editor.
  let(:host_component) do
    Class.new(Phlex::HTML) do
      register_element :lexxy_prompt

      def view_template
        render Forms::RichTextarea.new(name: "post[content]") do
          lexxy_prompt(trigger: "@", src: "/prompts/users")
        end
      end
    end
  end

  it "nests a child element inside the editor" do
    output = render_component(host_component.new)

    expect(output).to include(
      %(<lexxy-prompt trigger="@" src="/prompts/users"></lexxy-prompt></lexxy-editor>)
    )
  end

  it "still renders the editor with no block" do
    output = render_component(described_class.new(name: "post[content]"))

    expect(output).to include("<lexxy-editor")
    expect(output).to include('name="post[content]"')
  end

  it "yields the block inside the editor, not beside it" do
    output = render_component(described_class.new(name: "post[content]")) { "CONFIG" }

    expect(output).to include(">CONFIG</lexxy-editor>")
  end

  it "forwards a block through the form builder" do
    user = build_model(:user, name: "Ada")
    output = PhlexHelpers::FormContext.new(
      model: user, form_args: {},
      form_block: ->(f) { f.rich_textarea(:name) { "CONFIG" } }
    ).call

    expect(output).to include(">CONFIG</lexxy-editor>")
  end

  it "forwards a block through the rich_text_area alias" do
    user = build_model(:user, name: "Ada")
    output = PhlexHelpers::FormContext.new(
      model: user, form_args: {},
      form_block: ->(f) { f.rich_text_area(:name) { "CONFIG" } }
    ).call

    expect(output).to include(">CONFIG</lexxy-editor>")
  end

  # Lexxy's attachments need Active Storage's direct-upload endpoints on the
  # `<lexxy-editor>` element. Lexxy's own Rails tag helper sets them; this
  # component built the element itself and didn't, so every phlex-forms rich text
  # editor silently lost image uploads (cosmos, Aug 2026). Paths, not URLs: a
  # multi-host app must not pin uploads to whichever host rendered the page.
  context "with Active Storage direct uploads" do
    # A stand-in for Rails.application.routes.url_helpers.
    let(:url_helpers) do
      Module.new do
        module_function

        def rails_direct_uploads_path = "/rails/active_storage/direct_uploads"

        def rails_service_blob_path(signed_id, filename)
          "/rails/active_storage/blobs/redirect/#{signed_id}/#{filename}"
        end
      end
    end

    before do
      application = Struct.new(:routes).new(Struct.new(:url_helpers).new(url_helpers))
      stub_const("Rails", Module.new { define_singleton_method(:application) { application } })
    end

    it "wires the direct upload endpoints as paths" do
      output = render_component(described_class.new(name: "post[content]"))

      expect(output).to include(%(data-direct-upload-url="/rails/active_storage/direct_uploads"))
      expect(output).to include(
        %(data-blob-url-template="/rails/active_storage/blobs/redirect/:signed_id/:filename")
      )
    end

    it "lets the caller override them" do
      output = render_component(
        described_class.new(name: "post[content]", data: { direct_upload_url: "/custom/uploads" })
      )

      expect(output).to include(%(data-direct-upload-url="/custom/uploads"))
      expect(output).not_to include("/rails/active_storage/direct_uploads")
    end
  end

  context "without Rails" do
    it "renders the editor with no upload attributes" do
      output = render_component(described_class.new(name: "post[content]"))

      expect(output).to include("<lexxy-editor")
      expect(output).not_to include("data-direct-upload-url")
    end
  end
end
