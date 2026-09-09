# frozen_string_literal: true

# The model-bound form. Yields itself as the builder:
#
#   Form(model: @user) do |f|
#     f.field :email
#     f.field :role, as: :select, choices: roles
#     f.submit
#   end
#
# Derives scope/url/method from the model (including the polymorphic array form
# `model: [parent, child]`), emits the CSRF + method-override hidden fields, and
# always sets multipart encoding for non-GET forms so file inputs never silently
# fail to upload.
module Forms
  class Form < Phlex::HTML
    include Phlex::Rails::Helpers::FormAuthenticityToken if defined?(Phlex::Rails::Helpers::FormAuthenticityToken)
    include PhlexForms::Builder

    attr_reader :model, :scope, :url, :method, :errors, :validate, :theme

    # Rails form-builder compatibility: `f.object` / `f.object_name` mirror the
    # ActionView FormBuilder API so call sites that introspect the bound record
    # (`f.object.class.reflect_on_association(...)`) keep working.
    alias object model
    alias object_name scope

    def initialize(*modifiers, model: nil, scope: nil, url: nil, method: nil, validate: false,
                   field_variants: nil, theme: nil, live: nil, **options)
      if live
        raise ArgumentError,
          "live validation requires a Forms::Base subclass — the endpoint rebuilds the " \
          "form from its class, and an inline block cannot be serialized. Declare " \
          "`live model: #{record_from(model)&.class&.name || 'YourModel'}` on the class instead."
      end

      super()
      @base_modifiers = modifiers
      @field_variants = Array(field_variants)
      @theme = PhlexForms::Theme.resolve(theme)
      @options = options
      @model = record_from(model)
      # scope: false opts out of scoping entirely — bare field names for
      # reactive row editors / <template>-cloned rows. nil means "derive".
      @scope = scope == false ? nil : (scope&.to_s || derive_scope(@model))
      @url = url || derive_url(model)
      @method = method || derive_method(@model)
      @errors = (@model.errors if @model.respond_to?(:errors))
      @validate = validate
    end

    # Introspector for the bound model when client-side validation is enabled, or
    # a no-op Null otherwise. Callers can always call #data_attributes_for(attr).
    def validations_introspector
      @validations_introspector ||=
        if @validate
          Forms::Validations::Introspector.for(@model)
        else
          Forms::Validations::Introspector::Null.new
        end
    end

    def view_template(&)
      form(action: @url, accept_charset: "UTF-8", method: form_method, **form_attributes) do
        authenticity_token_field unless @method&.to_sym == :get
        method_field if @method && %i[get post].exclude?(@method.to_sym)
        yield self if block_given?
      end
    end

    # Return a Forms::Field for a name (used by the Builder mixin).
    def field_object(name, error_name: nil)
      Forms::Field.new(name:, model: @model, scope: @scope, errors: @errors, form: self, error_name:)
    end
    alias [] field_object # `f[:email].hidden` — Rails form-builder-style access

    def submit(*, **, &)
      render theme[:submit].new(*, model: @model, **, &)
    end

    def rich_textarea(name, *modifiers, **, &)
      render field_object(name).rich_textarea(*modifiers, **), &
    end
    alias rich_text_area rich_textarea

    def time_zone_select(name, *modifiers, selected: nil, **)
      render Forms::TimeZoneSelect.new(
        *modifiers,
        name: field_name(name),
        id: field_id(name),
        selected: selected || @model&.public_send(name),
        **
      )
    end

    # Nested attributes. Yields a FieldsForBuilder per association (single) or per
    # item (has_many), with the correctly-indexed nested scope.
    # nested_attributes: false nests under the raw name (no `_attributes` suffix)
    # for JSONB/hash columns that aren't Rails nested attributes.
    def fields_for(association_name, model = nil, nested_attributes: true, &)
      return unless block_given?

      associated = model || (@model.public_send(association_name) if @model.respond_to?(association_name))
      attributes_key = nested_attributes ? "#{association_name}_attributes" : association_name.to_s
      base_scope = @scope ? "#{@scope}[#{attributes_key}]" : attributes_key

      if collection?(associated)
        associated.each_with_index do |item, index|
          yield build_fields_for("#{base_scope}[#{index}]", item)
        end
      else
        yield build_fields_for(base_scope, associated)
      end
    end

    # Rails-style collection_check_boxes. Emits a hidden field so an empty
    # selection still submits, then yields a builder per collection item.
    def collection_check_boxes(name, collection, value_method, text_method, &)
      return unless block_given?

      input(type: "hidden", name: "#{field_name(name)}[]", value: "")
      current = Array(@model&.public_send(name))
      current_ids = current.map { |v| v.respond_to?(value_method) ? v.public_send(value_method) : v }

      collection.each do |item|
        item_value = item.public_send(value_method)
        item_text = text_method.is_a?(Proc) ? text_method.call(item) : item.public_send(text_method)
        yield Forms::CollectionCheckBoxBuilder.new(
          object: item, value: item_value, text: item_text,
          checked: current_ids.include?(item_value),
          name: "#{field_name(name)}[]", id: "#{field_id(name)}_#{item_value}"
        )
      end
    end

    # A batched checkbox group for an array-valued field (issue #9). Delegates to
    # Field#checkbox_group, which derives the checked set from the model.
    #   f.checkbox_group(:tag_ids, Tag.all, value: :id, label: :name, variant: :pill)
    def checkbox_group(name, collection, **)
      render field_object(name).checkbox_group(collection, **)
    end

    # Rails-style collection_select over an enumerable of records.
    def collection_select(name, collection, value_method, text_method, options = {}, html_options = {})
      choices = collection.map do |item|
        text = text_method.is_a?(Proc) ? text_method.call(item) : item.public_send(text_method)
        [text, item.public_send(value_method)]
      end
      choices = [[options[:prompt], ""]] + choices if options[:prompt]
      render field_object(name).select(choices, **options.except(:prompt), **html_options)
    end

    # Default variants prepended to every `field`'s inner input: global config
    # first, then this form's field_variants: (call-site modifiers stack last).
    def default_field_variants
      PhlexForms.config.field_variants + @field_variants
    end

    # Public name/id/value helpers for external components mirroring the Rails API.
    def field_name(name)  = @scope ? "#{@scope}[#{name}]" : name.to_s
    def field_id(name)    = @scope ? "#{@scope}_#{name}" : name.to_s
    def field_value(name) = field_object(name).field_value

    private

    # A genuine has_many collection (Array / ActiveRecord::Relation), NOT a
    # Hash-backed nested scope. A Hash responds to #each_with_index but is a
    # single nested record (a JSONB column), so iterating it would emit bogus
    # positional indices — scope[assoc][0][field] — instead of scope[assoc][field]
    # (issue #10). Enumerable-but-not-Hash covers Relations without requiring AR.
    def collection?(associated)
      associated.is_a?(Enumerable) && !associated.is_a?(Hash)
    end

    def build_fields_for(scope, item)
      Forms::FieldsForBuilder.new(
        model: item,
        scope:,
        errors: (item.errors if item.respond_to?(:errors)),
        parent_form: self
      )
    end

    # For a polymorphic array model, the record is the last element.
    def record_from(model)
      model.is_a?(Array) ? model.last : model
    end

    def form_method
      %i[get post].include?(@method.to_sym) ? @method : :post
    end

    def form_attributes
      attrs = @options.except(:class, :local, :multipart, :turbo_frame, :id, :data)
      attrs[:id] = @options[:id] if @options[:id]
      if (classes = form_classes)
        attrs[:class] = classes
      end
      attrs[:data] = (@options[:data] || {}).dup
      attrs[:data][:turbo] = "false" if @options[:local] == true
      attrs[:data][:turbo_frame] = @options[:turbo_frame] if @options[:turbo_frame]
      apply_validation_coordinator(attrs) if @validate
      attrs[:data].transform_values! { |v| v == false ? "false" : v }
      attrs[:enctype] = "multipart/form-data" unless @method&.to_sym == :get
      attrs
    end

    # When client-side validation is on, attach the form-level coordinator
    # controller (submit interceptor) and turn OFF the native browser validation
    # UI (novalidate) — the Stimulus layer owns error display.
    def apply_validation_coordinator(attrs)
      existing = attrs[:data][:controller].to_s
      # Derive the coordinator identifier from the introspector's prefix so the
      # form-level and field-level controllers can never drift (issue #12).
      coordinator = "#{Forms::Validations::Introspector::CONTROLLER_PREFIX}--form"
      attrs[:data][:controller] = [existing, coordinator].reject(&:empty?).join(" ")
      # Wire the coordinator's submit handler. Without this data-action the
      # controller connects but onSubmit never fires, so an invalid form is not
      # blocked client-side (issue #11). Joined with any caller-supplied action.
      existing_action = attrs[:data][:action].to_s
      submit_action = "submit->#{coordinator}#onSubmit"
      attrs[:data][:action] = [existing_action, submit_action].reject(&:empty?).join(" ")
      attrs[:novalidate] = true
    end

    def form_classes
      classes = []
      classes << "space-y-4" if @base_modifiers.include?(:spaced)
      classes << "space-y-6" if @base_modifiers.include?(:spacious)
      PhlexForms::ClassMerge.merge(classes.join(" "), @options[:class]).presence
    end

    def authenticity_token_field
      return unless respond_to?(:form_authenticity_token)

      token = form_authenticity_token
      input(type: "hidden", name: "authenticity_token", value: token) if token
    end

    def method_field
      input(type: "hidden", name: "_method", value: @method)
    end

    def derive_scope(record)
      return nil unless record

      if record.respond_to?(:model_name)
        record.model_name.param_key
      elsif record.is_a?(Symbol) || record.is_a?(String)
        record.to_s
      else
        record.class.name.underscore.tr("/", "_")
      end
    end

    # For an array model, build the url from the whole array (polymorphic nesting);
    # otherwise from the record.
    def derive_url(model)
      return "/" unless model

      record = record_from(model)
      persisted = record.respond_to?(:persisted?) && record.persisted?
      prefix = url_prefix(model, record)
      persisted ? "#{prefix}/#{record.to_param}" : prefix
    end

    def url_prefix(model, record)
      parents = model.is_a?(Array) ? model[0...-1] : []
      segments = parents.map { |p| "/#{p.class.name.underscore.pluralize}/#{p.to_param}" }
      "#{segments.join}/#{derive_scope(record).pluralize}"
    end

    def derive_method(record)
      record.respond_to?(:persisted?) && record.persisted? ? :patch : :post
    end
  end
end
