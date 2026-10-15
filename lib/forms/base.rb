# frozen_string_literal: true

module Forms
  # Declarative form classes: subclass, declare the fields in #fields, render.
  # Inside #fields, `self` IS the form — the whole builder surface (field, row,
  # group, Input, submit, fields_for, ...) is available as bare calls.
  #
  #   class UserForm < Forms::Base
  #     form_options :spaced
  #
  #     def fields
  #       field :email
  #       row { field :first_name; field :last_name }
  #       submit :primary
  #     end
  #   end
  #
  #   render UserForm.new(model: @user)
  #
  # A render-time block appends after the declared fields:
  #
  #   render UserForm.new(model: @user) { |f| f.Hidden(:token) }
  class Base < Form
    class << self
      # Class-level defaults, inherited and merged down the subclass chain
      # (instance args beat class defaults; subclass defaults beat parents'):
      #
      #   form_options :spaced, url: "/signup", validate: true
      #
      # A class macro: it runs while the form class body loads (at boot, on the
      # main Ractor) and stores Ractor-shareable copies of its arguments
      # (PhlexForms::Shareable.copy), so the readers work in any Ractor.
      # rubocop:disable ThreadSafety/ClassInstanceVariable
      def form_options(*modifiers, **defaults)
        @form_modifiers = PhlexForms::Shareable.copy(modifiers)
        @form_defaults = PhlexForms::Shareable.copy(defaults)
      end

      def form_modifiers
        inherited = superclass.respond_to?(:form_modifiers) ? superclass.form_modifiers : []
        (inherited + (@form_modifiers || [])).uniq
      end

      def form_defaults
        inherited = superclass.respond_to?(:form_defaults) ? superclass.form_defaults : {}
        inherited.merge(@form_defaults || {})
      end
      # rubocop:enable ThreadSafety/ClassInstanceVariable

      # Server-truth live validation via phlex-reactive (a soft dependency):
      #
      #   class UserForm < Forms::Base
      #     live model: User
      #     def fields = field(:email)
      #   end
      #
      # Blur/debounced input POST every field to a :validate action that runs
      # the REAL model validators and morphs the errors back in, focus intact.
      # Only Forms::Base subclasses can be live — the endpoint rebuilds the
      # form from its class; an inline block cannot be serialized.
      def live(model:, scope: nil, debounce: 300)
        unless reactive_available?
          raise PhlexForms::FeatureUnavailable,
            "#{name || 'this form'} declares `live` but the phlex-reactive gem is not " \
            "installed. Add `gem \"phlex-reactive\"` to your Gemfile, or use " \
            "`validate: true` for the client-side Stimulus mirror instead."
        end

        include Forms::Live

        setup_live(model_class: model, scope: scope || derive_live_scope(model), debounce:)
      end

      # Extracted so specs can exercise the FeatureUnavailable guard.
      def reactive_available?
        defined?(Phlex::Reactive::Component) ? true : false
      end

      private

      def derive_live_scope(model)
        model.respond_to?(:model_name) ? model.model_name.param_key : model.name.underscore.tr("/", "_")
      end
    end

    def initialize(*modifiers, **options)
      super(*(self.class.form_modifiers + modifiers).uniq, **self.class.form_defaults.merge(options))
    end

    # Renders Form's chrome (action/method/CSRF/enctype), then the declared
    # fields. `yield`/`block_given?` inside the inner block bind to
    # view_template's own block — the optional render-time block.
    def view_template
      super do
        fields
        yield self if block_given?
      end
    end

    # The hook name `fields` is verified free against Phlex::HTML (phlex 2.4.x)
    # and this gem (Form defines fields_for/field_object, never fields).
    def fields
      raise NotImplementedError, "#{self.class} must define #fields"
    end
  end
end
