# frozen_string_literal: true

module Forms
  module Validations
    # Introspects an ActiveModel class (or instance) and translates
    # each attribute's validators into a `data:` hash ready to merge
    # into a Phlex element. Phlex handles the `data-` prefixing and
    # underscore-to-hyphen conversion at render time.
    #
    # Sticks to validators whose semantics are reproducible client
    # side. Skips anything with `:if` / `:unless` / `:on` because
    # those need server context the browser doesn't have. Server
    # validation remains authoritative — the client side just
    # shortens the loop for the common cases.
    class Introspector
      # The Stimulus identifier prefix. Kept in sync with the file path the
      # controllers ship at (phlex_forms/controllers/validations/*_controller),
      # so lazyLoadControllersFrom("phlex_forms/controllers") resolves
      # `validations--length` → .../validations/length_controller (issue #12).
      CONTROLLER_PREFIX = "validations"

      # Validators we know how to mirror. Keys are the short class
      # name (without namespace), values are the controller suffix
      # appended to CONTROLLER_PREFIX. Matching on the short name
      # picks up both `ActiveModel::Validations::*` (form objects)
      # and `ActiveRecord::Validations::*` (AR models inherit a
      # parallel set of subclasses for uniqueness/etc.) without
      # listing both namespaces.
      SUPPORTED = {
        "PresenceValidator" => "presence",
        "LengthValidator" => "length",
        "FormatValidator" => "format",
        "NumericalityValidator" => "numericality",
        "InclusionValidator" => "inclusion",
        "ExclusionValidator" => "exclusion",
        "ConfirmationValidator" => "confirmation",
        "AcceptanceValidator" => "acceptance"
      }.freeze

      LENGTH_KEYS = %i[maximum minimum is].freeze

      NUMERICALITY_KEYS = %i[
        greater_than greater_than_or_equal_to
        less_than less_than_or_equal_to
        equal_to other_than
        only_integer odd even
      ].freeze

      # LengthValidator's per-case messages; each wins over `message:` on the
      # server, so the length controller checks them first. Each maps to the
      # bound it reports, so a Symbol resolves with that count.
      LENGTH_MESSAGE_KEYS = { too_long: :maximum, too_short: :minimum, wrong_length: :is }.freeze

      # Convenience: returns a null introspector for nil models so
      # callers don't need to guard.
      def self.for(model_or_class)
        return Null.new if model_or_class.nil?

        klass = model_or_class.is_a?(Class) ? model_or_class : model_or_class.class
        return Null.new unless klass.respond_to?(:validators_on)

        new(klass)
      end

      def initialize(model_class)
        @model_class = model_class
      end

      # Returns a hash of the shape:
      #   {
      #     controller: "validations--presence validations--length",
      #     validations__presence_required_value: "true",
      #     validations__length_maximum_value: "60",
      #   }
      #
      # Returns {} when no supported validators are present.
      # The double-underscore key encoding survives Phlex/Rails'
      # underscore-to-hyphen rewrite: `__` → `-` (deliberate).
      def data_attributes_for(attribute)
        validators = applicable_validators(attribute)
        return {} if validators.empty?

        controllers = []
        attrs = {}

        validators.each do |validator|
          suffix = SUPPORTED[validator.class.name.split("::").last]
          next unless suffix

          controllers << "#{CONTROLLER_PREFIX}--#{suffix}"
          value_attributes(suffix, validator, attribute).merge(message_attrs(suffix, validator, attribute))
            .each do |key, value|
            attrs[data_key(suffix, key)] = value
          end
        end

        return {} if controllers.empty?

        { controller: controllers.uniq.join(" ") }.merge(attrs)
      end

      private

      attr_reader :model_class

      # Phlex turns underscores in `data:` hash keys into hyphens
      # in the rendered HTML. To produce a key like
      # `data-validations--length-maximum-value` from a
      # Ruby symbol we need every "-" represented as "__" in the
      # symbol. That's what this method builds.
      def data_key(suffix, key)
        prefix = CONTROLLER_PREFIX.tr("-", "_")
        :"#{prefix}__#{suffix}_#{key}_value"
      end

      def applicable_validators(attribute)
        return [] unless model_class.respond_to?(:validators_on)

        model_class.validators_on(attribute).reject { |v| conditional?(v) }
      end

      def conditional?(validator)
        opts = validator.options
        opts[:if].present? || opts[:unless].present? || opts[:on].present?
      end

      def value_attributes(suffix, validator, attribute)
        case suffix
        when "presence" then presence_attrs
        when "length" then length_attrs(validator)
        when "format" then format_attrs(validator)
        when "numericality" then numericality_attrs(validator)
        when "inclusion", "exclusion" then collection_attrs(validator)
        when "confirmation" then confirmation_attrs(attribute)
        when "acceptance" then acceptance_attrs(validator)
        else {}
        end
      end

      # `message` (and length's `too_long_message` & co.) values, for the
      # validator's own `message:` options. Omitted when there is none, or when
      # it can't be resolved without a record, so the generic message stays.
      def message_attrs(suffix, validator, attribute)
        counts = suffix == "length" ? length_message_counts(validator) : {}
        options = counts.keys + [:message]
        options.each_with_object({}) do |option, attrs|
          text = Message.resolve(validator.options[option], model_class:, attribute:, count: counts[option])
          attrs[option == :message ? :message : :"#{option}_message"] = text if text
        end
      end

      def length_message_counts(validator)
        bounds = length_attrs(validator)
        LENGTH_MESSAGE_KEYS.to_h { |option, bound| [option, bounds[bound]&.to_i] }
      end

      def presence_attrs
        { required: "true" }
      end

      def length_attrs(validator)
        opts = validator.options
        attrs = {}

        LENGTH_KEYS.each do |key|
          attrs[key] = opts[key].to_s if opts.key?(key)
        end

        if opts.key?(:in) || opts.key?(:within)
          range = opts[:in] || opts[:within]
          attrs[:minimum] = range.min.to_s
          attrs[:maximum] = range.max.to_s
        end

        attrs[:allow_blank] = "true" if opts[:allow_blank]
        attrs[:allow_nil] = "true" if opts[:allow_nil]
        attrs
      end

      def format_attrs(validator)
        opts = validator.options
        regex = opts[:with]
        return {} unless regex.is_a?(Regexp)

        attrs = { pattern: js_regex_source(regex) }
        flags = js_regex_flags(regex)
        attrs[:flags] = flags unless flags.empty?
        attrs[:allow_blank] = "true" if opts[:allow_blank]
        attrs
      end

      # JS regex syntax is mostly compatible with Ruby's, but two
      # gotchas matter for the validators we'll be wiring up:
      #   - Ruby `\A` / `\z` anchors → JS `^` / `$`
      #   - Inline modifiers like `(?-mix:...)` need stripping
      def js_regex_source(regex)
        src = regex.source
        src = src.gsub(/\A\(\?[-mix]+:(.+)\)\z/, '\1') # strip wrapper modifiers
        src.gsub("\\A", "^").gsub("\\z", "$").gsub("\\Z", "$")
      end

      def js_regex_flags(regex)
        flags = []
        flags << "i" if regex.options.anybits?(Regexp::IGNORECASE)
        flags << "m" if regex.options.anybits?(Regexp::MULTILINE)
        flags.join
      end

      def numericality_attrs(validator)
        opts = validator.options
        attrs = {}

        NUMERICALITY_KEYS.each do |key|
          next unless opts.key?(key)

          value = opts[key]
          attrs[key] = value.is_a?(TrueClass) ? "true" : value.to_s
        end

        attrs[:allow_nil] = "true" if opts[:allow_nil]
        attrs[:allow_blank] = "true" if opts[:allow_blank]
        attrs
      end

      def collection_attrs(validator)
        list = validator.options[:in]
        return {} unless list.respond_to?(:to_a)

        attrs = { in: list.to_a.to_json }
        attrs[:allow_blank] = "true" if validator.options[:allow_blank]
        attrs
      end

      def confirmation_attrs(attribute)
        { match: "#{attribute}_confirmation" }
      end

      def acceptance_attrs(validator)
        accept = validator.options[:accept] || %w[1 true]
        { accept: Array(accept).map(&:to_s).to_json }
      end

      # No-op introspector returned for nil / non-AR models.
      class Null
        def data_attributes_for(_attribute)
          {}
        end
      end
    end
  end
end
