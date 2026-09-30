# frozen_string_literal: true

require "spec_helper"

describe "Forms components" do
  def render_form(model, **args, &)
    render_form_via(model, **args, &)
  end

  # Reuse the PhlexHelpers form renderer.
  def render_form_via(model, **args, &block)
    PhlexHelpers::FormContext.new(model:, form_args: args, form_block: block).call
  end

  describe "delegated leaf variants" do
    let(:user) { build_model(:user, name: "Ada") }

    it "stacks positional daisyui modifiers on the input" do
      output = render_form(user) { |f| f.field(:name, :primary, :lg) }
      expect(output).to include('class="input input-primary input-lg w-full"')
    end

    it "treats v4 :bordered as a no-op (v5 has the border on the base class)" do
      output = render_form(user) { |f| f.field(:name, :bordered, :primary) }
      expect(output).not_to include("input-bordered")
      expect(output).to include("input-primary")
    end
  end

  describe "width default vs caller width" do
    # A caller width must REPLACE the w-full default, not stack with it — with
    # both on the element, stylesheet source order (not author intent) decides,
    # and w-full winning is how admin filter selects went full-width (zazu#2934).
    it "replaces the w-full default with a caller width on Select" do
      output = render_component(Forms::Select.new(:sm, name: "status", choices: [%w[Active active]], class: "w-36"))
      expect(output).to match(/class="[^"]*w-36[^"]*"/)
      expect(output).not_to include("w-full")
    end

    it "replaces the w-full default with a caller width on Input" do
      output = render_component(Forms::Input.new(:sm, type: "date", name: "start_date", class: "w-28"))
      expect(output).to match(/class="[^"]*w-28[^"]*"/)
      expect(output).not_to include("w-full")
    end

    it "keeps the w-full default when the caller passes no width" do
      output = render_component(Forms::Input.new(name: "email"))
      expect(output).to match(/class="[^"]*w-full[^"]*"/)
    end

    it "composes w-full with min-w-/max-w- caller classes (different properties)" do
      output = render_component(Forms::Select.new(name: "event_type", choices: [], class: "min-w-32"))
      expect(output).to match(/class="[^"]*w-full[^"]*min-w-32[^"]*"/)
    end

    it "emits no width at all with full_width: false" do
      output = render_component(Forms::Input.new(name: "email", full_width: false))
      expect(output).not_to include("w-full")
    end
  end

  describe "caller class vs hint/error defaults" do
    it "lets a caller's size and spacing replace the hint defaults" do
      output = render_component(Forms::FieldHint.new(text: "No spam", class: "text-xs mt-2"))
      expect(output).to include('class="text-base-content/60 text-xs mt-2"')
    end

    it "lets a caller's size replace the error default and keeps the error color" do
      output = render_component(Forms::FieldError.new(message: "is invalid", class: "text-xs"))
      expect(output).to include('class="text-error mt-1 text-xs"')
    end
  end

  describe "Radio (issue #13)" do
    it "keeps each radio's own value instead of the model's current value" do
      # field_attributes carries value: field_value; splatted after the explicit
      # radio value it used to clobber it, so every radio submitted the model's
      # value (or, for a new record, nothing).
      user = build_model(:user, role: nil)

      output = render_form(user) do |f|
        f.Radio(:role, "manager")
        f.Radio(:role, "member")
      end

      expect(output).to include('value="manager"')
      expect(output).to include('value="member"')
      expect(output).to include('name="user[role]"')
    end

    it "checks the radio whose value matches the model, not all of them" do
      user = build_model(:user, role: "manager")

      output = render_form(user) do |f|
        f.Radio(:role, "manager")
        f.Radio(:role, "member")
      end

      expect(output).to match(/value="manager"[^>]*checked/)
      expect(output).not_to match(/value="member"[^>]*checked/)
    end

    it "still lets an explicit value: option win" do
      user = build_model(:user, role: nil)

      output = render_form(user) { |f| f.Radio(:role, "manager", value: "override") }

      expect(output).to include('value="override"')
    end
  end

  describe "hidden_field (Rails FormBuilder migration aid)" do
    it "renders a scoped hidden input with an explicit value: override" do
      user = build_model(:user, name: "Ada")

      output = render_form(user) do |f|
        f.hidden_field(:accepted_terms_document_id, value: 42)
      end

      expect(output).to include('type="hidden"')
      expect(output).to include('name="user[accepted_terms_document_id]"')
      expect(output).to include('id="user_accepted_terms_document_id"')
      expect(output).to include('value="42"')
    end

    it "binds the value from the model when none is passed" do
      user = build_model(:user, token: "abc123")

      output = render_form(user) { |f| f.hidden_field(:token) }

      expect(output).to include('type="hidden"')
      expect(output).to include('name="user[token]"')
      expect(output).to include('value="abc123"')
    end

    it "renders under the plain theme too (bare hidden input)" do
      user = build_model(:user, token: "abc123")

      output = render_form(user, theme: :plain) { |f| f.hidden_field(:token) }

      expect(output).to include('<input type="hidden"')
      expect(output).to include('name="user[token]"')
      expect(output).to include('value="abc123"')
    end
  end

  # A hidden field must never carry visual styling: daisyui's `.input`
  # (display: inline-flex) overrides WebKit's NON-!important UA rule
  # `input[type=hidden] { display: none }`, so a styled hidden field renders as
  # an empty box and becomes a focusable phantom tab stop in Safari. Chromium's
  # UA rule is !important, which is why the bug only shows there.
  describe "Hidden (bare, unstyled)" do
    let(:user) { build_model(:user, token: "abc123") }

    it "renders a bare hidden input with the model-bound name, id, and value" do
      output = render_form(user) { |f| f.Hidden(:token) }

      expect(output).to include('<input type="hidden" name="user[token]" id="user_token" value="abc123">')
    end

    it "emits no styling classes (the WebKit focusability fix)" do
      output = render_form(user) { |f| f.Hidden(:token) }

      expect(output).not_to match(/<input[^>]*type="hidden"[^>]*class=/)
      expect(output).not_to include("w-full")
    end

    it "carries no error state when the field is invalid" do
      user.errors.add(:token, "is invalid")

      output = render_form(user) { |f| f.Hidden(:token) }

      expect(output).not_to match(/<input[^>]*type="hidden"[^>]*(error|aria-invalid)/)
    end

    it "lets a caller value: win over the model value" do
      output = render_form(user) { |f| f.Hidden(:token, value: 42) }

      expect(output).to include('value="42"')
      expect(output).not_to include('value="abc123"')
    end

    it "passes caller attributes through verbatim" do
      output = render_form(user) { |f| f.Hidden(:token, tabindex: -1, data: { controller: "autosubmit" }) }

      expect(output).to include('tabindex="-1"')
      expect(output).to include('data-controller="autosubmit"')
    end

    # Every route to a hidden field converges on the bare leaf — including the
    # Input escape hatch, which resolves :hidden as an input type.
    {
      "f.Hidden" => ->(f) { f.Hidden(:token) },
      "f.hidden_field" => ->(f) { f.hidden_field(:token) },
      "f[:token].hidden" => ->(f) { f.render(f[:token].hidden) },
      "f.Input positional :hidden" => ->(f) { f.Input(:token, :hidden) },
      "f.Input type: :hidden" => ->(f) { f.Input(:token, type: :hidden) }
    }.each do |label, call|
      it "renders a bare hidden input via #{label}" do
        output = render_form(user) { |f| call.call(f) }

        expect(output).to include('<input type="hidden" name="user[token]" id="user_token" value="abc123">')
        expect(output).not_to include("w-full")
      end
    end

    # The `field` verb wraps its control in a Control (label + form-control div);
    # what matters here is that the input itself is bare.
    it "renders a bare hidden input via the field verb (as: and positional)" do
      as_kwarg = render_form(user) { |f| f.field(:token, as: :hidden) }
      positional = render_form(user) { |f| f.field(:token, :hidden) }

      expect([as_kwarg, positional]).to all(
        include('<input type="hidden" name="user[token]" id="user_token" value="abc123">')
      )
      expect([as_kwarg, positional]).to all(satisfy { |out| !out.include?('class="input') })
    end

    it "renders identically under the plain theme" do
      daisy = render_form(user) { |f| f.Hidden(:token) }
      plain = render_form(user, theme: :plain) { |f| f.Hidden(:token) }

      expect(plain).to eq(daisy)
      expect(plain).to include('<input type="hidden" name="user[token]" id="user_token" value="abc123">')
    end
  end

  describe "fields_for (has_many nested attributes)" do
    it "renders indexed nested attribute names" do
      child = Class.new do
        include ActiveModel::Model

        def self.name = "LineItem"
        attr_accessor :description
      end
      parent = build_model(:invoice, line_items: [child.new(description: "A"), child.new(description: "B")])

      output = render_form(parent) do |f|
        f.fields_for(:line_items) { |lf| lf.field(:description) }
      end

      expect(output).to include('name="invoice[line_items_attributes][0][description]"')
      expect(output).to include('name="invoice[line_items_attributes][1][description]"')
    end
  end

  describe "collection_check_boxes" do
    it "emits the empty-array hidden field and a checkbox per item" do
      item = Struct.new(:id, :label)
      collection = [item.new(1, "One"), item.new(2, "Two")]
      user = build_model(:user, role_ids: [1])

      output = render_form(user) do |f|
        f.collection_check_boxes(:role_ids, collection, :id, :label) do |b|
          f.render(b.check_box)
          f.render(b.label)
        end
      end

      expect(output).to include('<input type="hidden" name="user[role_ids][]" value="">')
      expect(output).to include('name="user[role_ids][]"')
      expect(output).to include("One")
      expect(output).to include("Two")
    end
  end

  describe "client-side validation wiring" do
    let(:partner) do
      build_model(:partner, title: nil, slug: nil,
        validations: -> { validates :title, presence: true, length: { maximum: 60 } })
    end

    it "attaches the coordinator + novalidate when validate: true" do
      output = render_form(partner, validate: true, &:submit)
      expect(output).to include("novalidate")
      expect(output).to include("validations--form")
    end

    it "wires the submit handler via a data-action (issue #11)" do
      # Without this, the coordinator connects but onSubmit is never invoked, so
      # submitting an invalid form is not blocked client-side.
      output = render_form(partner, validate: true, &:submit)
      expect(output).to include("submit->validations--form#onSubmit")
    end

    it "preserves a caller-supplied data-action alongside the coordinator action" do
      output = render_form(partner, validate: true, data: { action: "click->thing#go" }, &:submit)
      expect(output).to include("click->thing#go")
      expect(output).to include("submit->validations--form#onSubmit")
    end

    it "wires per-field validator controllers from the model" do
      output = render_form(partner, validate: true) { |f| f.field(:title) }
      expect(output).to include("validations--presence validations--length")
      expect(output).to include('data-validations--length-maximum-value="60"')
    end

    it "opts a field out with validate: false" do
      output = render_form(partner, validate: true) { |f| f.field(:title, validate: false) }
      expect(output).not_to include("validations--presence")
    end
  end
end
