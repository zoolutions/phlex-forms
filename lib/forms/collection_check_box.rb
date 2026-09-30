# frozen_string_literal: true

module Forms
  # A single checkbox within a collection_check_boxes group.
  class CollectionCheckBox < Phlex::HTML
    def initialize(name:, id:, value:, checked:, **options)
      @name = name
      @id = id
      @value = value
      @checked = checked
      @options = options
      super()
    end

    def view_template
      input(
        type: "checkbox",
        name: @name,
        id: @id,
        value: @value,
        class: DaisyUI::ClassMerge.merge("checkbox", @options[:class]),
        checked: @checked || nil
      )
    end
  end
end
