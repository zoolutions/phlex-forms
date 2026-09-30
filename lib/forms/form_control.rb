# frozen_string_literal: true

module Forms
  # Wraps a field in the daisyui form-control layout: optional label on top, the
  # field (yielded block), then an error (if present) or a hint. This is the
  # workhorse behind the Control-first `f.field` API and the explicit `f.Control`
  # escape hatch.
  class FormControl < Phlex::HTML
    # label_id:/hint_id: give the label and hint stable ids so a group control
    # (checkbox_group's div[role="group"], which a plain `for`/`id` can't name)
    # can reference them via aria-labelledby / aria-describedby (issue #17).
    def initialize(*modifiers, label: nil, hint: nil, error: nil, for: nil, required: false,
                   label_id: nil, hint_id: nil, **options)
      @modifiers = modifiers
      @label = label
      @hint = hint
      @error = error
      @field_id = grab(for:)
      @required = required
      @label_id = label_id
      @hint_id = hint_id
      @options = options
      super()
    end

    def view_template(&)
      div(class: control_classes, **@options.except(:class)) do
        render Forms::Label.new(text: @label, for: @field_id, required: @required, id: @label_id) if @label

        yield if block_given?

        if @error
          render Forms::FieldError.new(message: @error)
        elsif @hint
          render Forms::FieldHint.new(text: @hint, id: @hint_id)
        end
      end
    end

    private

    def control_classes
      horizontal = "flex flex-row items-center gap-4" if @modifiers.include?(:horizontal)
      DaisyUI::ClassMerge.merge("form-control w-full", horizontal, @options[:class])
    end
  end
end
