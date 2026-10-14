# frozen_string_literal: true

module Forms
  module Validations
    # Accepts an inline rules hash and produces the same data-* hash
    # shape that `Introspector#data_attributes_for` returns. Used when
    # a caller wants client-side validation on a form not backed by
    # an ActiveModel object (e.g. plain form objects, marketplace
    # submissions that bypass the model in test setup, etc.).
    #
    # Supported shape:
    #
    #   ManualRules.new(
    #     length: { maximum: 60, minimum: 3 },
    #     presence: true,
    #     format: { with: /\A[a-z]+\z/i, message: "letters only" },
    #     numericality: { greater_than_or_equal_to: 0 },
    #     inclusion: { in: %w[a b c] },
    #     exclusion: { in: %w[admin] },
    #     confirmation: true,
    #     acceptance: true,
    #   )
    class ManualRules
      def initialize(rules)
        @rules = rules
      end

      def data_attributes
        # Build a tiny ad-hoc model whose validators reproduce the
        # rules, then delegate to the Introspector. Saves us
        # reimplementing the per-validator → data-attr conversion in
        # two places.
        klass = build_adhoc_model
        Introspector.new(klass).data_attributes_for(:value)
      end

      private

      attr_reader :rules

      def build_adhoc_model
        captured_rules = rules
        Class.new do
          include ActiveModel::Model
          include ActiveModel::Validations

          attr_accessor :value, :value_confirmation

          captured_rules.each do |key, opts|
            case key
            when :presence
              validates :value, presence: opts.is_a?(Hash) ? opts : true if opts
            when :length
              validates :value, length: opts
            when :format
              validates :value, format: opts
            when :numericality
              validates :value, numericality: opts
            when :inclusion
              validates :value, inclusion: opts
            when :exclusion
              validates :value, exclusion: opts
            when :confirmation
              validates :value, confirmation: opts.is_a?(Hash) ? opts : true if opts
            when :acceptance
              validates :value, acceptance: opts.is_a?(Hash) ? opts : { accept: %w[1 true] }
            end
          end

          def self.name
            "Forms::Validations::ManualRules::Adhoc"
          end
        end
      end
    end
  end
end
