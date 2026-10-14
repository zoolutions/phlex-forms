# frozen_string_literal: true

module Forms
  module Validations
    # Turns a validator's `message:` option into the text the browser should
    # show, so the client mirror says what the server would (issue #41).
    #
    #   - a String is emitted as is; `%{count}`-style placeholders stay in place
    #     for the Stimulus controller to fill, as it does for its own messages.
    #   - a Symbol is resolved on the server through ActiveModel's lookup chain
    #     (`<scope>.errors.models.<model>.attributes.<attr>.<key>` ... then
    #     `errors.messages.<key>`), in the current locale.
    #   - anything else (a Proc needs a record) resolves to nil, so the
    #     controller keeps its generic message.
    #
    # Mirrors `ActiveModel::Error.generate_message` against the class alone: the
    # introspector never instantiates the model.
    class Message
      # Interpolations the browser fills in, kept as literal placeholders.
      PLACEHOLDERS = { count: "%{count}", value: "%{value}" }.freeze

      def self.resolve(message, model_class:, attribute:)
        case message
        when String then message
        when Symbol then new(model_class, attribute).translate(message)
        end
      end

      def initialize(model_class, attribute)
        @model_class = model_class
        @attribute = attribute.to_s
      end

      def translate(key)
        return unless defined?(I18n)

        first, *rest = lookup_keys(key)
        I18n.translate(first, **interpolations, default: rest, raise: true)
      rescue StandardError
        nil
      end

      private

      attr_reader :model_class, :attribute

      def lookup_keys(key)
        model_keys(key) + [:"errors.attributes.#{attribute}.#{key}", :"errors.messages.#{key}"]
      end

      def model_keys(key)
        return [] unless model_class.respond_to?(:i18n_scope) && model_class.respond_to?(:lookup_ancestors)

        scope = model_class.i18n_scope
        keys = model_class.lookup_ancestors.flat_map do |klass|
          i18n_key = klass.model_name.i18n_key
          [:"#{scope}.errors.models.#{i18n_key}.attributes.#{attribute}.#{key}",
            :"#{scope}.errors.models.#{i18n_key}.#{key}"]
        end
        keys << :"#{scope}.errors.messages.#{key}"
      end

      def interpolations
        names = {}
        names[:model] = model_class.model_name.human if model_class.respond_to?(:model_name)
        names[:attribute] = model_class.human_attribute_name(attribute) if model_class.respond_to?(:human_attribute_name)
        PLACEHOLDERS.merge(names)
      end
    end
  end
end
