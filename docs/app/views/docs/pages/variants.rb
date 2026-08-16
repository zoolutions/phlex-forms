# frozen_string_literal: true

# daisyUI variants: positional stacking + form-level and global defaults.
class Views::Docs::Pages::Variants < DocsUI::Page
  title "Variants"
  eyebrow "Guide"

  def lead = "daisyUI variants stack positionally on any field — with defaults per form, per class, or globally."

  def content
    positional
    defaults
    precedence
  end

  private

  def positional
    DocsUI::Section("Positional variants") do
      md <<~'MD'
        Any positional symbol that isn't a type override is a daisyUI variant,
        stacked onto the inner input exactly as the
        [daisyui gem](https://github.com/zoolutions/daisyui) stacks them:
      MD
      DocsUI::Code(<<~'RUBY')
        f.field :email, :primary, :sm       # input input-primary input-sm
        f.field :bio, :ghost                # textarea textarea-ghost
        f.Input(:name, :primary, :lg)       # escape hatch: same stacking
        f.submit "Save", :primary, :wide    # btn btn-primary btn-wide
      RUBY
      md <<~'MD'
        An invalid field appends the error variant automatically (unless you
        already passed a color), so server-side errors restyle the control with
        no extra code.
      MD
    end
  end

  def defaults
    DocsUI::Section("Form-level and global defaults") do
      md <<~'MD'
        Real apps repeat the same variants on nearly every field. Set them once:
      MD
      DocsUI::Code(<<~'RUBY')
        # per form (inline)
        Form(model: @user, field_variants: [:primary, :sm]) { |f| f.field :email }

        # per form class — inherited down the subclass chain
        class ApplicationForm < Forms::Base
          form_options field_variants: [:primary]
        end

        # global
        PhlexForms.configure { |c| c.field_variants = [:sm] }
      RUBY
      md <<~'MD'
        Defaults apply to every `field`'s inner input (never labels or hints),
        and `fields_for` builders inherit the parent form's.
      MD
    end
  end

  def precedence
    DocsUI::Section("Precedence") do
      md <<~'MD'
        Variants concatenate **global → form-level → call-site**, so the most
        local wins the class stack:
      MD
      DocsUI::Code(<<~'RUBY')
        PhlexForms.configure { |c| c.field_variants = [:sm] }

        Form(model: @user, field_variants: [:primary]) do |f|
          f.field :email          # input-sm input-primary
          f.field :name, :lg      # input-sm input-primary input-lg — :lg wins
        end
      RUBY
      DocsUI::Callout(:tip) do
        plain "Under the Plain theme, variants are accepted and ignored — the "
        plain "same form class renders unstyled without touching a call site."
      end
    end
  end
end
