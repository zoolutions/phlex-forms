# frozen_string_literal: true

module Forms
  # A model-bound tag/chip input, composed from phlex-reactive's CLIENT-ONLY tag
  # primitives (form state, no token, zero round trips). phlex-forms owns the
  # polished chrome — daisyUI styling, model binding, the hidden comma-joined
  # field — while phlex-reactive owns the behavior contract.
  #
  #   f.field :tags, as: :tags, suggestions: %w[Ruby Rails Hotwire Postgres]
  #   f.field :tags, as: :tags, suggestions: { "Postgres" => "postgres database db sql" }
  #
  # Submits ONE comma-joined param (`user[tags] = "Ruby,Rails"`), the primitive's
  # wire contract — the model splits it (an `attribute :tags` + a `tags=` writer,
  # or an ActiveModel array type).
  #
  # This file is autoloaded ONLY when Phlex::Reactive is present (the Forms::Live
  # gate in lib/phlex_forms.rb) because it includes ClientBindings at class level.
  # The reactive_tags_* client helpers require phlex-reactive >= 0.11.4.
  #
  # It uses the reactive_tags_add/option/remove helpers for the chip/query/option
  # behavior, and the ROOT's wire attrs come from the 0.12.2 escape-hatch sugar:
  # reactive_tags(name: @name) takes the per-instance wire name verbatim ("user[tags]")
  # — the class-level reactive_scope compile can't express it — validated at render;
  # reactive_filter(input: "#…_query") targets the query input by id so it never
  # submits, and (unlike the old raw -input-only attr) also emits
  # data-reactive-filter-option so the 0.12.x client type-ahead actually runs
  # (issue #6 Caveats 1 & 2).
  class TagField < Phlex::HTML
    include Phlex::Reactive::ClientBindings

    def initialize(*modifiers, name:, id:, value: nil, suggestions: [], error: false,
                   placeholder: "Add a tag…", **attributes)
      @modifiers = modifiers
      @name = name # "user[tags]" — instance-dynamic
      @id = id
      @value = value.is_a?(Array) ? value.compact.join(",") : value.to_s
      @suggestions = normalize_suggestions(suggestions)
      @error = error
      @placeholder = placeholder
      @attributes = attributes
      super()
    end

    def view_template
      # Standalone: THIS div is the reactive root. Inside a Forms::Live form the
      # widget renders rootless (Forms::RootlessTagField) — the outer <form> is
      # the root and carries these tag attrs — so the form owns the hidden field.
      div(**mix(reactive_root(id: "#{@id}_widget"), root_tag_attributes, class: root_classes)) do
        body
      end
    end

    # The query input's id — the reactive_filter(input:) target and the id the
    # search input itself carries. Public so Forms::Live can derive the same id
    # when it hoists the tag wire attrs onto the <form> root (rootless widget).
    def self.query_id(id) = "#{id}_query"

    private

    # The root's tag wire attrs, via the 0.12.2 escape-hatch sugar (Caveats 1 & 2):
    # reactive_tags(name:) takes the instance-dynamic wire name verbatim and
    # validates it at render; reactive_filter(input:) targets the query input by
    # #id (so it never submits a stray param) and emits both filter selectors the
    # 0.12.x client needs to run the type-ahead. Both are private helpers from
    # ClientBindings — Forms::Live has its own copies (it's a reactive component)
    # and calls them directly when hoisting these onto the <form> root.
    def root_tag_attributes
      mix(
        reactive_tags(name: @name),
        reactive_filter(input: "##{self.class.query_id(@id)}")
      )
    end

    # The widget body WITHOUT its root wrapper — shared with the rootless variant
    # so chip/template/suggestion markup never drifts between the two.
    def body
      input(type: :hidden, name: @name, id: @id, value: @value)

      div(class: list_classes, data: { reactive_tags_list: true }) do
        current_tags.each { |tag| chip(tag) } # server-rendered first paint
      end
      template(data: { reactive_tags_template: true }) { chip }

      # Enter adds free text; mix AFTER reactive_listnav so Enter prefers a
      # highlighted option. NO name → never submits.
      input(**mix(reactive_listnav, reactive_tags_add, query_attributes))

      ul(class: menu_classes) do
        @suggestions.each { |tag, haystack| suggestion(tag, haystack) }
      end
    end

    def normalize_suggestions(suggestions)
      return suggestions if suggestions.is_a?(Hash)

      Array(suggestions).to_h { |tag| [tag, tag.to_s.downcase] }
    end

    def current_tags = @value.split(",").map(&:strip).reject(&:empty?)

    def query_attributes
      {
        id: self.class.query_id(@id), type: "search", autocomplete: "off",
        placeholder: @placeholder, class: input_classes,
        "aria-invalid": @error || nil
      }.compact
    end

    # A preloaded suggestion that adds its tag on click (reactive_tags_option
    # forces type="button" + role="option" + the tagsPick action + the tag
    # param). The filter haystack rides alongside via mix.
    def suggestion(tag, haystack)
      li do
        button(**mix(reactive_tags_option(tag),
          { class: option_classes, data: { reactive_filter_text: haystack } })) { tag }
      end
    end

    # One method, both forms: with a tag = a server-rendered chip (its remove
    # button carries the tag param); without = the <template> prototype (the
    # client fills the text node + the remove button's tag param per clone).
    def chip(tag = nil)
      span(class: chip_classes, data: { reactive_tag: tag }) do
        span(data: { reactive_tag_text: true }) { tag }
        button(**mix(reactive_tags_remove(tag),
          { class: remove_classes, aria: { label: "Remove" } })) { "×" }
      end
    end

    # --- styling seams (the Plain twin overrides these to bare/empty) ---

    def root_classes = "tag-field flex flex-col gap-2"
    def list_classes = "flex flex-wrap gap-1"
    def menu_classes = "menu bg-base-200 rounded-box"
    def option_classes = nil
    def chip_classes = "badge badge-primary gap-1"
    def remove_classes = "cursor-pointer"
    def input_classes = DaisyUI::ClassMerge.merge("input w-full", @attributes[:class])
  end
end
