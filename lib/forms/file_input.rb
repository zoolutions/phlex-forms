# frozen_string_literal: true

module Forms
  # A model-bound `<input type="file">`, delegating to DaisyUI::FileInput.
  class FileInput < Phlex::HTML
    include PhlexForms::DelegatedField

    def initialize(*modifiers, name: nil, id: nil, multiple: false, accept: nil,
                   error: false, disabled: false, required: false, full_width: true, **attributes)
      @modifiers = normalize_modifiers(modifiers)
      # Rails file_field parity: a multiple input needs an array param name, or
      # the browser collapses the selection into one scalar file — which a host
      # app's `params.expect(attr: [])` then silently discards.
      @name = multiple && name && !name.to_s.end_with?("[]") ? "#{name}[]" : name
      @id = id
      @multiple = multiple
      @accept = accept
      @error = error
      @disabled = disabled
      @required = required
      @full_width = full_width
      @attributes = attributes
      super()
    end

    def view_template
      attrs = binding_attributes(accept: @accept)
      attrs[:multiple] = true if @multiple
      render DaisyUI::FileInput.new(*daisy_modifiers, **attrs)
    end
  end
end
