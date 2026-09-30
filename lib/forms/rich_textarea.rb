# frozen_string_literal: true

module Forms
  # A rich-text editor backed by the Lexxy `<lexxy-editor>` custom element for
  # ActionText. Optional feature: requires ActionText/Lexxy in the host app.
  # Renders an editor bound to the field; when the value is an ActionText::RichText
  # its HTML body is used as the initial content.
  class RichTextarea < Phlex::HTML
    register_element :lexxy_editor

    def initialize(*modifiers, name:, id: nil, value: nil, **options)
      @modifiers = modifiers
      @name = name
      @id = id || name.to_s.gsub(/[\[\]]/, "_").gsub(/_+$/, "")
      @value = value
      @options = options
      apply_direct_upload_defaults
      super()
    end

    # Lexxy configures the editor through CHILD elements — `<lexxy-prompt>` for
    # @mentions, `<lexxy-code-language-picker>` for code blocks — so the block
    # has to reach the element, not be dropped.
    def view_template(&)
      lexxy_editor(
        name: @name,
        id: @id,
        value: formatted_value,
        class: editor_classes,
        **@options.except(:class, :error),
        &
      )
    end

    private

    # Lexxy uploads attachments through Active Storage's direct-upload
    # endpoints, read off the element. Lexxy's own Rails tag helper sets them;
    # this component builds the element itself, so without these an editor
    # silently loses image uploads. Paths, not URLs: a multi-host app must not
    # pin uploads to whichever host rendered the page first.
    #
    # Fully guarded — the gem has no Rails dependency, and a host without
    # Active Storage (or with its own values) is left alone.
    def apply_direct_upload_defaults
      helpers = rails_url_helpers or return

      data = (@options[:data] ||= {})
      data[:direct_upload_url] ||= helpers.rails_direct_uploads_path
      data[:blob_url_template] ||= helpers.rails_service_blob_path(":signed_id", ":filename")
    rescue StandardError
      nil
    end

    def rails_url_helpers
      return unless defined?(Rails) && Rails.respond_to?(:application)

      helpers = Rails.application&.routes&.url_helpers
      return unless helpers.respond_to?(:rails_direct_uploads_path)
      return unless helpers.respond_to?(:rails_service_blob_path)

      helpers
    end

    def formatted_value
      return nil if @value.nil? || (@value.respond_to?(:blank?) && @value.blank?)

      content = @value.respond_to?(:body) ? @value.body&.to_html : @value.to_s
      content.to_s.empty? ? nil : "<div>#{content}</div>"
    end

    def editor_classes
      DaisyUI::ClassMerge.merge(@options[:class], "lexxy-content")
    end
  end
end
