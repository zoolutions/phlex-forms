# frozen_string_literal: true

# The pitch: what phlex-forms is, the three pillars, and where to go next.
class Views::Docs::Pages::Overview < DocsUI::Page
  title "Overview"
  eyebrow "Getting started"

  def lead = "A model-bound form builder for Phlex — one call per field, types inferred from the model, forms as first-class classes."

  def content
    what_it_is
    the_pillars
    a_taste
    where_next
  end

  private

  def what_it_is
    DocsUI::Section("What it is") do
      md <<~'MD'
        phlex-forms gives [Phlex](https://www.phlex.fun) apps a form builder that
        actually leans into Phlex. `field :email` renders a label, an input, and
        an error (or hint) in **one call** — the input type, the `required` flag,
        and even the choices are inferred from the bound model. Every field is a
        thin binding layer over a real [daisyUI](https://daisyui.com) component,
        and a theme seam swaps the whole look for bare semantic HTML when a
        project doesn't use daisyUI at all.
      MD
    end
  end

  def the_pillars
    DocsUI::Section("The three pillars") do
      md <<~'MD'
        **The model already knows.** A boolean column renders a toggle, an
        ActiveRecord enum a humanized select, a `belongs_to` a collection select
        over the association, a text column a textarea, an attachment a file
        input. `as:` and `choices:` are overrides, not requirements — see
        [Type inference](/docs/inference).

        **Forms are classes.** Phlex's whole thesis is views-as-objects, so forms
        shouldn't be anonymous blocks with `f.` on every line. Subclass
        `Forms::Base`, declare fields where `self` *is* the form, render it
        anywhere — see [Form classes](/docs/form-classes).

        **Validation without a mirror.** With
        [phlex-reactive](https://phlex-reactive.zoolutions.llc) installed,
        `live model: User` runs your **real** ActiveModel validators server-side
        on blur — uniqueness, `:if`/`:unless`, confirmation — and morphs the
        errors back in with focus preserved. No duplicated validation logic, no
        second message catalog — see [Live validation](/docs/live-validation).
      MD
    end
  end

  def a_taste
    DocsUI::Section("A taste") do
      DocsUI::Code(<<~'RUBY', filename: "app/forms/user_form.rb")
        class UserForm < Forms::Base
          live model: User                 # real validators, live, focus preserved

          def fields                       # self IS the form — no f. prefix
            field :email                   # name → type=email, required inferred
            field :role                    # AR enum → select, humanized
            field :country                 # belongs_to → select over the association
            field :notify                  # boolean column → toggle
            field :bio                     # text column → textarea
            row do
              field :first_name
              field :last_name
            end
            submit :primary
          end
        end
      RUBY
      DocsUI::Code(<<~'RUBY', filename: "app/views/users/new.rb")
        render UserForm.new(model: @user)
      RUBY
      md <<~'MD'
        For one-offs, the inline builder does the same with a yielded form:
      MD
      DocsUI::Code(<<~'RUBY')
        Form(model: @user) do |f|
          f.field :email, hint: "We never spam."
          f.field :bio
          f.submit :primary
        end
      RUBY
    end
  end

  def where_next
    DocsUI::Section("Where next") do
      md <<~'MD'
        - [Installation](/docs/installation) — the gem and its optional live-validation companion.
        - [Quick start](/docs/quick-start) — from a model to a live-validating form.
        - [The field API](/docs/field-api) — every option on the primary verb.
        - [Theming](/docs/theming) — daisyUI by default, plain semantic HTML on demand.
      MD
    end
  end
end
