# frozen_string_literal: true

# What the Ractor blocks below reach through constants (a Ractor block must be
# capture-free). A Struct is the model: an ActiveModel class keeps its
# validators in class state of its own.
module RactorCanary
  User = Struct.new(:email, :password, :admin, :bio, keyword_init: true)

  SignupForm = Class.new(Forms::Base) do
    form_options :spaced, url: "/signup", data: { controller: "signup" }, field_variants: [:primary]
  end

  JoinForm = Class.new(SignupForm) { form_options url: "/join" }

  if defined?(Phlex::Reactive)
    LiveForm = Class.new(Forms::Base) do
      live model: User, scope: :user, debounce: 150
      live_permit :email, :bio
      live_deny :bio
      live_tags :tags, suggestions: %w[Ruby Rails]
    end
  end
end

# Tier 3 of conformance-kit, on Ruby 4.0 (skipped with the reason below it):
# with the configuration finalized, field inference and the class-level form
# settings run inside a non-main Ractor and agree with the main Ractor.
RSpec.describe "phlex-forms inside a non-main Ractor" do
  before { PhlexForms.finalize! }

  context "when resolving a field's options" do
    let(:subject_call) do
      lambda do |name|
        user = RactorCanary::User.new(email: "ada@example.com", admin: true)
        field = Forms::Field.new(name:, model: user, scope: "user", errors: nil, form: nil)
        inferred = PhlexForms::Inference.resolve(model: user, name:)
        [field.field_name, field.field_id, field.field_value, field.field_label, field.required?,
          field.input.class, inferred.as, inferred.attributes]
      end
    end

    it_behaves_like "runs inside a non-main Ractor", inputs: [:email]
    it_behaves_like "runs inside a non-main Ractor", inputs: [:admin]
  end

  context "when resolving a theme and an icon" do
    let(:subject_call) do
      lambda do
        [PhlexForms::Theme.resolve(nil)[:input], PhlexForms::Theme.resolve(:plain)[:select],
          PhlexForms.config.render_icon("chevron-down")]
      end
    end

    it_behaves_like "runs inside a non-main Ractor"
  end

  context "when reading form_options" do
    let(:subject_call) do
      lambda do
        [RactorCanary::SignupForm.form_modifiers, RactorCanary::SignupForm.form_defaults,
          RactorCanary::JoinForm.form_defaults]
      end
    end

    it_behaves_like "runs inside a non-main Ractor"
  end

  if defined?(Phlex::Reactive)
    context "when reading a live form's settings" do
      let(:subject_call) do
        lambda do
          form = RactorCanary::LiveForm
          [form.live_model_class, form.live_scope, form.live_debounce, form.live_tags_declaration,
            form.live_permitted_attributes(RactorCanary::User.new)]
        end
      end

      it_behaves_like "runs inside a non-main Ractor"
    end
  end

  context "when rendering a field",
    pending: "Phlex reads its non-shareable Phlex::ATTRIBUTE_CACHE constant on every element " \
             "with attributes; a per-Ractor cache is pending upstream (yippee-fun/phlex#1055)" do
    let(:subject_call) do
      lambda do
        user = RactorCanary::User.new(email: "ada@example.com")
        form = Forms::Form.new(model: user, scope: "user", url: "/users", theme: :plain)
        form.field_object(:email).input.call
      end
    end

    it_behaves_like "runs inside a non-main Ractor"
  end
end
