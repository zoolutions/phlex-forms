# frozen_string_literal: true

module Forms
  # Inline hint/help text shown beneath a field.
  class FieldHint < Phlex::HTML
    def initialize(text: nil, **options)
      @text = text
      @options = options
      super()
    end

    def view_template
      return unless @text

      p(class: classes, **@options.except(:class)) { @text }
    end

    private

    def classes
      DaisyUI::ClassMerge.merge("text-base-content/60 text-sm mt-1", @options[:class])
    end
  end
end
