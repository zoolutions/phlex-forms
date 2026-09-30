# frozen_string_literal: true

module Forms
  # Side-by-side fields in a responsive grid: stacked on mobile, `columns`
  # across from the sm breakpoint. The class strings are literals (not
  # interpolated) so host Tailwind scanners pick them up.
  #
  #   f.row { f.field :first_name; f.field :last_name }
  #   f.row(columns: 3) { ... }
  class Row < Phlex::HTML
    COLUMN_CLASSES = {
      2 => "sm:grid-cols-2",
      3 => "sm:grid-cols-3",
      4 => "sm:grid-cols-4"
    }.freeze

    def initialize(columns: 2, **options)
      @columns = columns
      @options = options
      super()
    end

    def view_template(&)
      div(class: row_classes, **@options.except(:class), &)
    end

    private

    def row_classes
      DaisyUI::ClassMerge.merge("grid grid-cols-1 gap-4", COLUMN_CLASSES[@columns], @options[:class])
    end
  end
end
