# frozen_string_literal: true

# The theme seam: daisy by default, Plain for non-daisyUI projects, custom
# per-role overrides.
class Views::Docs::Pages::Theming < DocsUI::Page
  title "Theming"
  eyebrow "Guide"

  def lead = "Every component resolves through a theme — daisyUI by default, bare semantic HTML on demand."

  def content
    the_seam
    the_plain_theme
    selecting
    custom_roles
  end

  private

  def the_seam
    DocsUI::Section("The theme seam") do
      md <<~'MD'
        A theme is a map from component **roles** (`:input`, `:select`,
        `:control`, `:label`, `:submit`, `:row`, …) to component classes. The
        stable interface is the **binding contract** — the leaf initializer
        signatures (`*modifiers, name:, id:, value:, error:, required:, …`) —
        so the same form class renders under any theme.

        The **daisy theme** is the default: every leaf delegates its markup and
        variant stacking to a real daisyUI component. The **Plain theme**
        renders the same form with no daisyUI classes, for a project that
        doesn't ship daisyUI's CSS.
      MD
    end
  end

  def the_plain_theme
    DocsUI::Section("The Plain theme") do
      md <<~'MD'
        Plain renders bare semantic HTML with **zero styling classes** and the
        same binding: names, ids, values, `required`, the hidden
        unchecked-value pair for checkboxes. Variants are accepted and ignored.
        Instead of styling, it emits stable hooks for your own CSS:

        - `aria-invalid` on invalid controls,
        - `role="alert"` + `data-field-error` on error messages,
        - `data-field-hint` on hints, `data-form-row` on rows,
        - a semantic `fieldset`/`legend` for groups, `abbr` for the required marker.

        Documented degradations: `searchable:` selects fall back to the native
        select (no choices.js) and `rich_textarea` falls back to a plain
        textarea.
      MD
    end
  end

  def selecting
    DocsUI::Section("Selecting a theme") do
      DocsUI::Code(<<~'RUBY')
        render UserForm.new(model: @user, theme: :plain)   # per render

        class AdminForm < Forms::Base
          form_options theme: :plain                       # per class
        end

        PhlexForms.configure { |c| c.theme = :plain }      # global default
      RUBY
      md <<~'MD'
        `theme:` accepts `:daisy`, `:plain`, or a `PhlexForms::Theme` instance.
      MD
    end
  end

  def custom_roles
    DocsUI::Section("Overriding single roles") do
      md <<~'MD'
        `Theme#with` swaps individual roles — your component just has to honor
        the role's initializer contract. Subclassing the shipped component is
        the easy way to stay contract-compatible:
      MD
      DocsUI::Code(<<~'RUBY', filename: "config/initializers/phlex_forms.rb")
        class BrandInput < Forms::Plain::Input
          def view_template
            input(type: @type, value: @value.to_s, class: "brand-input", **unstyled_attributes.except(:class))
          end
        end

        PhlexForms.configure do |c|
          c.theme = PhlexForms::Theme.resolve(:plain).with(input: BrandInput)
        end
      RUBY
      DocsUI::Callout(:note) do
        plain "The daisy leaves only reference "
        code { "DaisyUI::*" }
        plain " inside view_template, so they load fine without the gem — they "
        plain "just must not be rendered. Theme resolution guarantees that."
      end
    end
  end
end
