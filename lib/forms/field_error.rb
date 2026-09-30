# frozen_string_literal: true

module Forms
  # Inline validation error shown beneath a field. Uses the same visual treatment
  # (`text-error text-sm`) the client-side validation controllers apply, so a
  # server-rendered error and a live client-rendered one look identical.
  class FieldError < Phlex::HTML
    def initialize(message: nil, **options)
      @message = message
      @options = options
      super()
    end

    def view_template
      return unless @message

      p(class: classes) { @message }
    end

    private

    def classes
      DaisyUI::ClassMerge.merge("text-error text-sm mt-1", @options[:class])
    end
  end
end
