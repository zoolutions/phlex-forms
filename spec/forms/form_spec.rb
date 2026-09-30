# frozen_string_literal: true

require "spec_helper"

describe Forms::Form do
  let(:user) do
    build_model(
      :user,
      email: "a@b.c", bio: nil, role: "admin", notify: nil,
      validations: -> { validates :email, presence: true }
    )
  end

  # `render_form(model, url:) { |f| ... }` is provided by PhlexHelpers and renders
  # a real `Form(model:) { |f| ... }` through a kit context.

  describe "the Control-first #field API" do
    it "renders label + input + hint and infers type and required from the model" do
      output = render_form(user) { |f| f.field(:email, hint: "No spam") }

      expect(output).to include('<div class="form-control w-full">')
      # label with required marker (inferred from the presence validator)
      expect(output).to include("Email")
      expect(output).to include('<span class="text-error ml-1">*</span>')
      # type inferred from the attribute name; value bound; required attribute set
      expect(output).to include('type="email"')
      expect(output).to include('name="user[email]"')
      expect(output).to include('id="user_email"')
      expect(output).to include('value="a@b.c"')
      expect(output).to include("required")
      # hint rendered
      expect(output).to include("No spam")
    end

    it "renders a select when as: :select with choices" do
      output = render_form(user) do |f|
        f.field(:role, as: :select, choices: [%w[Admin admin], %w[User user]])
      end

      expect(output).to match(/<select[^>]*class="select w-full"/)
      expect(output).to include('name="user[role]"')
      expect(output).to include('id="user_role"')
      expect(output).to include('<option value="admin" selected>Admin</option>')
      expect(output).to include('<option value="user">User</option>')
    end

    it "renders a textarea when as: :textarea" do
      output = render_form(user) { |f| f.field(:bio, as: :textarea, rows: 5) }

      expect(output).to match(/<textarea[^>]*class="textarea w-full"/)
      expect(output).to include('name="user[bio]"')
      expect(output).to include('rows="5"')
    end

    it "renders a toggle (with the hidden unchecked field) when as: :toggle" do
      output = render_form(user) { |f| f.field(:notify, as: :toggle) }

      expect(output).to include('<input type="hidden" name="user[notify]" value="0">')
      expect(output).to match(/<input[^>]*type="checkbox"[^>]*class="toggle"/)
      expect(output).to include('name="user[notify]"')
      expect(output).to include('value="1"')
    end

    it "omits the required marker for a non-validated attribute" do
      output = render_form(user) { |f| f.field(:bio) }

      # bio has no presence validator
      expect(output).not_to include("id=\"user_bio\"\" required")
    end

    it "lets label: false suppress the label" do
      output = render_form(user) { |f| f.field(:email, label: false) }

      expect(output).not_to include("<label")
    end

    it "shows a validation error instead of the hint when the field is invalid" do
      user.errors.add(:email, "is invalid")
      output = render_form(user) { |f| f.field(:email, hint: "No spam") }

      expect(output).to include("Email is invalid")
      expect(output).not_to include("No spam")
      expect(output).to include("input-error")
    end
  end

  describe "escape-hatch component API" do
    it "renders a bare input via f.Input with an explicit modifier" do
      output = render_form(user) { |f| f.Input(:email, :primary) }

      expect(output).to include('type="email"')
      expect(output).to include("input-primary")
    end

    it "wraps custom content via f.Control" do
      output = render_form(user) do |f|
        f.Control(:email, label: "Your email") { f.Input(:email, :primary) }
      end

      expect(output).to include("Your email")
      # daisyui v5: the base `input` class carries the border; :primary composes on top.
      expect(output).to include("input input-primary")
    end
  end

  describe "form element and model binding" do
    it "exposes #object / #object_name for Rails form-builder compatibility" do
      model = build_model(:user, email: "x@y.z")
      form = described_class.new(model:, url: "/users")

      expect(form.object).to be(model)
      expect(form.object_name).to eq("user")
    end

    it "exposes f[:name] as a Forms::Field accessor" do
      form = described_class.new(model: build_model(:user, email: "x@y.z"), url: "/users")

      expect(form[:email]).to be_a(Forms::Field)
      expect(form[:email].field_label).to eq("Email")
    end

    it "derives scope, url, patch method and multipart for a persisted record" do
      persisted = build_model(:user, email: "x@y.z")
      def persisted.persisted? = true
      def persisted.to_param = "42"

      output = render_form(persisted, &:submit)

      expect(output).to include('action="/users/42"')
      expect(output).to include('<input type="hidden" name="_method" value="patch">')
      expect(output).to include('enctype="multipart/form-data"')
    end

    it "supports a polymorphic array model (scope + nested url from the array)" do
      post = build_model(:post)
      def post.persisted? = true
      def post.to_param = "7"
      comment = build_model(:comment, body: nil)

      output = render_form([post, comment]) { |f| f.field(:body) }

      # scope is the child, not "array"
      expect(output).to include('name="comment[body]"')
      # url nests under the parent
      expect(output).to include('action="/posts/7/comments"')
    end
  end

  describe "model-driven inference through #field" do
    it "renders a toggle for a boolean attribute without as:" do
      model = build_model(:user, notify: nil, validations: -> { attribute :notify, :boolean })

      output = render_form(model) { |f| f.field(:notify) }

      expect(output).to match(/<input[^>]*type="checkbox"[^>]*class="toggle"/)
      expect(output).to include('name="user[notify]"')
    end

    it "renders a humanized select for an enum, with the current value selected" do
      model = build_model(:user, role: "power_user")
      model.class.define_singleton_method(:defined_enums) do
        { "role" => { "power_user" => 0, "admin" => 1 } }
      end

      output = render_form(model) { |f| f.field(:role) }

      expect(output).to include('<option value="power_user" selected>Power user</option>')
      expect(output).to include('<option value="admin">Admin</option>')
    end

    it "renders an association select named by the foreign key, showing :country errors" do
      country = Struct.new(:id, :name)
      countries = Class.new do
        define_singleton_method(:all) { [country.new(1, "Sweden"), country.new(2, "Germany")] }
      end
      reflection_class = Struct.new(:name, :macro, :foreign_key, :klass, keyword_init: true) do
        def polymorphic? = false
      end
      model = build_model(:user, country_id: 2)
      reflection = reflection_class.new(
        name: :country, macro: :belongs_to, foreign_key: "country_id", klass: countries
      )
      model.class.define_singleton_method(:reflect_on_association) do |n|
        reflection if n.to_sym == :country
      end
      model.errors.add(:country, "must exist")

      output = render_form(model) { |f| f.field(:country) }

      expect(output).to include('name="user[country_id]"')
      expect(output).to include('<option value="2" selected>Germany</option>')
      expect(output).to include("Country must exist")
    end

    it "renders a select when choices: are given without as:" do
      model = build_model(:user, role: "admin")

      output = render_form(model) { |f| f.field(:role, choices: [%w[Admin admin], %w[User user]]) }

      expect(output).to include('<option value="admin" selected>Admin</option>')
    end

    it "emits validator-derived attributes, losing to caller options" do
      model = build_model(
        :user, handle: nil,
        validations: -> { validates :handle, length: { maximum: 30 } }
      )

      expect(render_form(model) { |f| f.field(:handle) }).to include('maxlength="30"')
      expect(render_form(model) { |f| f.field(:handle, maxlength: 10) }).to include('maxlength="10"')
    end
  end

  describe "unscoped mode, JSONB nesting, and value introspection" do
    it "emits bare field names and ids when scope: false" do
      output = render_form(user, scope: false) { |f| f.field(:email) }

      expect(output).to include('name="email"')
      expect(output).to include('id="email"')
      expect(output).not_to include("user[email]")
    end

    it "keeps deriving the scope from the model when scope: nil" do
      output = render_form(user, scope: nil) { |f| f.field(:email) }

      expect(output).to include('name="user[email]"')
    end

    it "nests fields_for under the raw name when nested_attributes: false" do
      settings = build_model(:settings, locale: "en")

      output = render_form(user) do |f|
        f.fields_for(:settings, settings, nested_attributes: false) do |s|
          s.field(:locale)
        end
      end

      expect(output).to include('name="user[settings][locale]"')
      expect(output).not_to include("settings_attributes")
    end

    it "treats a Hash-backed association as a single nested scope, not a collection" do
      # A JSONB column returns a populated Hash. A Hash responds to
      # #each_with_index, so the old branch iterated it as [key, value] pairs,
      # emitting name="record[profile][0][phone]", [1], ... (issue #10).
      profile = { "phone" => "555", "city" => "NYC" }
      record = build_model(:record, profile:)

      output = render_form(record) do |f|
        f.fields_for(:profile, profile, nested_attributes: false) do |pf|
          pf.field(:phone)
        end
      end

      expect(output).to include('name="record[profile][phone]"')
      expect(output).not_to include("record[profile][0]")
      expect(output).not_to include("record[profile][1]")
    end

    it "exposes field_value alongside field_name and field_id" do
      captured = nil
      render_form(user) do |f|
        captured = [f.field_name(:email), f.field_id(:email), f.field_value(:email)]
      end

      expect(captured).to eq(["user[email]", "user_email", "a@b.c"])
    end
  end

  describe "form-level field variants" do
    after { PhlexForms.reset_configuration! }

    it "applies field_variants: to every field's inner input" do
      output = render_form(user, field_variants: [:sm]) { |f| f.field(:email) }

      expect(output).to include("input-sm")
    end

    it "puts call-site modifiers after form-level variants so they win the stack" do
      output = render_form(user, field_variants: [:sm]) { |f| f.field(:email, :lg) }

      # daisyui 1.x joins both sizes (sm before lg); 2.x merges the conflict
      # down to lg. Either way, the last size class on the input is the winner.
      sizes = output[/<input[^>]*class="([^"]*)"/, 1].split.grep(/\Ainput-(xs|sm|md|lg|xl)\z/)
      expect(sizes.last).to eq("input-lg")
    end

    it "applies globally configured variants beneath form-level ones" do
      PhlexForms.configure { |c| c.field_variants = [:primary] }

      output = render_form(user) { |f| f.field(:email) }

      expect(output).to include("input-primary")
    end

    it "inherits the parent form's variants through fields_for" do
      settings = build_model(:settings, locale: "en")

      output = render_form(user, field_variants: [:primary]) do |f|
        f.fields_for(:settings, settings) { |s| s.field(:locale) }
      end

      expect(output).to include("input-primary")
    end
  end

  describe "submit button" do
    it "defaults to the create label for a new record" do
      output = render_form(user) { |f| f.submit(:primary) }

      expect(output).to match(/<button[^>]*class="btn btn-primary"[^>]*type="submit"/)
      expect(output).to include("Create User")
    end
  end
end
