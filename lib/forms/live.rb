# frozen_string_literal: true

module Forms
  # Server-truth live validation via phlex-reactive: the whole form is one
  # reactive component. Each input's blur (and a debounced form-wide input
  # trigger) POSTs every field to a single :validate action, which assigns a
  # whitelisted slice to the model, runs the REAL ActiveModel validators —
  # uniqueness, :if/:unless, confirmation, :on context all work — and replies
  # with a focus-preserving morph. Nothing is ever persisted.
  #
  # Enabled through the Forms::Base macro (inline forms cannot be live — the
  # endpoint rebuilds the component from its class, and a caller-supplied
  # block cannot be serialized):
  #
  #   class UserForm < Forms::Base
  #     live model: User, debounce: 300
  #     def fields
  #       field :email
  #       field :password
  #       field :password_confirmation
  #     end
  #   end
  #
  # Identity is STATE-backed (not reactive_record): the token signs the
  # model's GlobalID when persisted (nil for new records — reactive_record
  # cannot round-trip an unsaved draft) plus the `touched` field list, so
  # error display state survives every round trip tamper-proof, with zero
  # client-side bookkeeping.
  module Live
    extend ActiveSupport::Concern
    include Phlex::Reactive::Component

    # Registers the raw-hash param type the :validate schema is declared with.
    # Called from the engine initializer (the registry freezes after boot);
    # test suites call it from their spec helper.
    def self.register_param_type!
      return if Phlex::Reactive.param_type?(:form_attributes)

      Phlex::Reactive.param_type(:form_attributes) do |value|
        value.is_a?(Hash) ? value : Phlex::Reactive::ParamSchema::DROP
      end
    end

    class_methods do
      # live (setup_live), live_permit, live_deny and live_tags are class macros:
      # they run while the form class body loads (at boot, on the main Ractor)
      # and store Ractor-shareable values (PhlexForms::Shareable.copy), so the
      # readers work in any Ractor.
      # rubocop:disable ThreadSafety/ClassInstanceVariable
      def setup_live(model_class:, scope:, debounce:)
        @live_model_class = model_class
        @live_scope = PhlexForms::Shareable.copy(scope.to_s)
        @live_debounce = PhlexForms::Shareable.copy(debounce)
        reactive_state :model_gid, :touched
        action :validate, params: { scope.to_sym => :form_attributes, _touch: :string }
        # phlex-reactive >= 0.11 defaults verify_authorized ON: an action that
        # completes without an authorization call raises AuthorizationNotVerified
        # and rolls back (#168). :validate is a deliberate no-persist, read-only
        # pass — it assigns, validates, and discards; native submit stays
        # authoritative — so it needs no authorization. Guarded so it's a no-op
        # on older phlex-reactive that lacks the macro.
        skip_verify_authorized :validate if respond_to?(:skip_verify_authorized)
      end

      def live_model_class = @live_model_class || inherited_live(:live_model_class)
      def live_scope       = @live_scope || inherited_live(:live_scope)
      def live_debounce    = @live_debounce || inherited_live(:live_debounce)

      # Narrow (live_permit) or trim (live_deny) the attributes the :validate
      # action may assign. Default: the model's column/attribute names plus
      # every validated attribute (and its _confirmation twin).
      def live_permit(*attrs) = @live_permit = PhlexForms::Shareable.copy(attrs.map(&:to_s))
      def live_deny(*attrs)   = @live_deny = PhlexForms::Shareable.copy(attrs.map(&:to_s))

      # Lift a tag field onto the form's reactive root so live :validate sees its
      # comma-joined value. The widget renders ROOTLESS (no nested reactive root),
      # so the outer <form> DOM-owns the hidden tags field; its wire attrs ride on
      # the form root (see #form_attributes). The declared tag name is
      # auto-permitted for :validate assignment.
      #
      #   class PostForm < Forms::Base
      #     live model: Post
      #     live_tags :tags, suggestions: %w[Ruby Rails]
      #     def fields = field(:tags, as: :tags)
      #   end
      #
      # phlex-reactive's tag controller reads ONE data-reactive-tags-field per
      # root, so a live form lifts AT MOST ONE tag field — a second raises.
      def live_tags(name, suggestions: [])
        if @live_tags
          raise ArgumentError,
            "a live form can lift at most one tag field onto its reactive root " \
            "(already declared live_tags #{@live_tags[:name].inspect}); render the " \
            "second as a standalone `field #{name.inspect}, as: :tags` (it stays " \
            "non-live)."
        end

        @live_tags = PhlexForms::Shareable.copy({ name: name.to_sym, suggestions: })
      end

      def live_tags_declaration = @live_tags || inherited_live(:live_tags_declaration)

      def live_permitted_attributes(model)
        permitted = @live_permit || derived_live_attributes(model)
        tag = live_tags_declaration
        permitted |= [tag[:name].to_s] if tag
        permitted - (@live_deny || [])
      end
      # rubocop:enable ThreadSafety/ClassInstanceVariable

      private

      def inherited_live(reader)
        superclass.respond_to?(reader) ? superclass.public_send(reader) : nil
      end

      def derived_live_attributes(model)
        klass = model.class
        names = []
        names.concat(klass.attribute_names.map(&:to_s)) if klass.respond_to?(:attribute_names)
        if klass.respond_to?(:validators)
          klass.validators.each do |validator|
            validator.attributes.each do |attr|
              names << attr.to_s
              names << "#{attr}_confirmation" if validator.is_a?(ActiveModel::Validations::ConfirmationValidator)
            end
          end
        end
        names.uniq
      end
    end

    # Two construction modes: the app renders `new(model:)`; the endpoint
    # rebuilds `new(model_gid:, touched:)` from the signed state (see
    # Component::DSL.from_identity — only declared state keys round-trip).
    def initialize(*modifiers, model: nil, model_gid: nil, touched: nil, **)
      model ||= locate_live_model(model_gid)
      @touched = Array(touched).map(&:to_s)
      super(*modifiers, model:, **)
      @model_gid = (@model.to_gid.to_s if signed_model_gid?)
      # A form re-rendered after a failed submit (classic 422) arrives with
      # errors already on the model — surface them without requiring touches.
      @touched |= @errors.attribute_names.map(&:to_s) if @errors.respond_to?(:attribute_names)
    end

    # Streamable's #id contract: the reactive root's stable DOM id.
    def id
      @options[:id] || "#{@model.respond_to?(:persisted?) && @model.persisted? ? 'edit' : 'new'}_#{@scope}"
    end

    # Assign → validate → morph. The reply preserves the focused input and its
    # caret (Idiomorph); the fresh token re-signs the updated touched set.
    # `_touch` is the wire key (underscored so it can never collide with a
    # model attribute) — the schema splats it back as this keyword.
    def validate(_touch: nil, **posted) # rubocop:disable Lint/UnderscorePrefixedVariableName
      @touched |= [_touch.to_s] if _touch
      assign_live_attributes(posted[self.class.live_scope.to_sym])
      @model.validate
      reply.morph
    end

    # The <form> element is the reactive root: id + controller + signed token,
    # plus the debounced whole-form input trigger (input events bubble; blur
    # triggers live per-input via Live::Field because Stimulus params are
    # per-element).
    def form_attributes
      attrs = super
      attrs = mix(
        attrs,
        reactive_root(id: attrs[:id] || id),
        on(:validate, event: "input", debounce: self.class.live_debounce)
      )
      # Hoist a declared tag field's wire attrs onto the form root so the rootless
      # widget (rendered in the block) is driven by this root, which then DOM-owns
      # its hidden field. Name/id derived through field_name/field_id — the same
      # path the rootless render uses, so the [name=…]/#…_query selectors match.
      # This form IS a reactive component, so it has reactive_tags/reactive_filter
      # itself — the same 0.12.2 escape-hatch sugar Forms::TagField uses, emitting
      # both filter selectors the client needs (issue #6 Caveats 1 & 2).
      tag = self.class.live_tags_declaration
      return attrs unless tag

      query_id = Forms::TagField.query_id(field_id(tag[:name]))
      mix(attrs,
        reactive_tags(name: field_name(tag[:name])),
        reactive_filter(input: "##{query_id}"))
    end

    # Untouched fields get no error set, so nothing flashes before the user
    # leaves a field; each input carries its blur _touch trigger.
    def field_object(name, error_name: nil)
      show_errors = touched?(name) || touched?(error_name)
      Forms::Live::Field.new(
        name:, model: @model, scope: @scope, form: self, error_name:,
        errors: (show_errors ? @errors : nil),
        live_trigger: on(:validate, event: "blur", _touch: name.to_s)
      )
    end

    def touched?(name)
      name && @touched.include?(name.to_s)
    end

    def locate_live_model(model_gid)
      return GlobalID::Locator.locate(model_gid) if model_gid.present?

      self.class.live_model_class.new
    end

    def signed_model_gid?
      @model.respond_to?(:to_gid) && @model.respond_to?(:persisted?) && @model.persisted?
    end

    # Whitelisted assignment through public writers. Values are validated and
    # rendered, never saved; use live_permit/live_deny to adjust the surface.
    def assign_live_attributes(attrs)
      return if attrs.blank?

      permitted = self.class.live_permitted_attributes(@model)
      attrs.each do |key, value|
        key = key.to_s
        next unless permitted.include?(key)

        setter = :"#{key}="
        @model.public_send(setter, value) if @model.respond_to?(setter)
      end
    end

    # ActiveSupport::Concern's own list of the concerns this one includes
    # (Phlex::Reactive::Component): filled while this module body loads and
    # only read after, when a form class includes Forms::Live. Frozen, so the
    # module holds no mutable state.
    @_dependencies.freeze
  end
end
