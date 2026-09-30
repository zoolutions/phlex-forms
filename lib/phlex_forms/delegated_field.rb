# frozen_string_literal: true

module PhlexForms
  # Shared helpers for the model-bound leaf components that delegate their markup
  # and variants to a daisyui gem component (DaisyUI::Input/Textarea/Select/...).
  #
  # A host component sets @modifiers, @error, @disabled, @required, @full_width,
  # and @attributes in its initializer, then calls #daisy_modifiers and
  # #binding_attributes to assemble the delegated component's arguments.
  module DelegatedField
    # daisyui v4 `:bordered` is a no-op in v5 (base component class has the
    # border); accept it silently so v4-era call sites don't break.
    IGNORED_MODIFIERS = %i[bordered].freeze

    private

    def normalize_modifiers(modifiers)
      modifiers - IGNORED_MODIFIERS
    end

    # Append :error when the field is invalid and the caller didn't already pass
    # a color modifier, so daisyui emits the *-error class.
    def daisy_modifiers
      return @modifiers if !@error || @modifiers.include?(:error)

      @modifiers + [:error]
    end

    # name/id + disabled/required booleans + a w-full class (unless full_width is
    # false), merged with the caller's passthrough attributes. Excludes internal
    # keys (:error, :value, :class, :placeholder handled per-component).
    def binding_attributes(**extra)
      attrs = {
        name: @name,
        id: @id,
        class: width_class,
        **@attributes.except(:error, :value, :class),
        **extra
      }
      attrs[:disabled] = true if @disabled
      attrs[:required] = true if @required
      attrs.compact
    end

    # Handed to the daisyui component as parts: its class merge lets a caller
    # width (`w-36`) REPLACE the default instead of stacking with it (zazu#2934).
    def width_class
      return @attributes[:class] unless @full_width

      ["w-full", *@attributes[:class]]
    end

    # Unstyled variant of binding_attributes for the Plain theme: caller classes
    # pass through verbatim, no width class, and an invalid field is flagged via
    # aria-invalid instead of an error variant class.
    def unstyled_attributes(**extra)
      attrs = {
        name: @name,
        id: @id,
        class: @attributes[:class],
        **@attributes.except(:error, :value, :class),
        **extra
      }
      attrs[:disabled] = true if @disabled
      attrs[:required] = true if @required
      attrs[:"aria-invalid"] = true if @error
      attrs.compact
    end
  end
end
