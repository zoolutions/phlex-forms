# frozen_string_literal: true

require "spec_helper"

describe PhlexForms::Inference do
  def resolve(model, name, **)
    described_class.resolve(model:, name:, **)
  end

  # A stand-in for an ActiveRecord association/attachment reflection.
  let(:reflection_class) do
    Struct.new(:name, :macro, :foreign_key, :klass, keyword_init: true) do
      def polymorphic? = false
    end
  end

  let(:country_class) do
    country = Struct.new(:id, :name)
    Class.new do
      define_singleton_method(:all) { [country.new(1, "Sweden"), country.new(2, "Germany")] }
    end
  end

  describe "explicit overrides (precedence 1-3)" do
    it "lets as: win over everything" do
      model = build_model(:user, notify: nil, validations: -> { attribute :notify, :boolean })

      expect(resolve(model, :notify, as: :checkbox).as).to eq(:checkbox)
    end

    it "lets a positional type modifier win over the column type" do
      model = build_model(:user, age: nil, validations: -> { attribute :age, :boolean })

      expect(resolve(model, :age, modifiers: [:number]).as).to eq(:number)
    end

    it "implies :select when choices: are given" do
      model = build_model(:user, role: "admin")

      expect(resolve(model, :role, choices: [%w[Admin admin]]).as).to eq(:select)
    end
  end

  describe "model structure (precedence 4)" do
    it "infers :rich_textarea from an ActionText rich-text association" do
      model = build_model(:post, body: nil)
      reflection = reflection_class.new(name: :rich_text_body, macro: :has_one)
      model.class.define_singleton_method(:reflect_on_association) do |n|
        reflection if n.to_sym == :rich_text_body
      end

      expect(resolve(model, :body).as).to eq(:rich_textarea)
    end

    it "infers :file from an ActiveStorage attachment (multiple for has_many)" do
      model = build_model(:post, avatar: nil, photos: nil)
      reflections = {
        avatar: reflection_class.new(name: :avatar, macro: :has_one_attached),
        photos: reflection_class.new(name: :photos, macro: :has_many_attached)
      }
      model.class.define_singleton_method(:reflect_on_attachment) { |n| reflections[n.to_sym] }

      single = resolve(model, :avatar)
      expect(single.as).to eq(:file)
      expect(single.multiple).to be(false)

      many = resolve(model, :photos)
      expect(many.as).to eq(:file)
      expect(many.multiple).to be(true)
    end

    it "infers a humanized select from an ActiveRecord enum" do
      model = build_model(:user, role: "power_user")
      model.class.define_singleton_method(:defined_enums) do
        { "role" => { "power_user" => 0, "admin" => 1 } }
      end

      result = resolve(model, :role)
      expect(result.as).to eq(:select)
      expect(result.choices).to eq([["Power user", "power_user"], %w[Admin admin]])
    end

    it "infers an association select from belongs_to, rewriting to the foreign key" do
      model = build_model(
        :user, country_id: nil,
        validations: -> { validates :country, presence: true }
      )
      reflection = reflection_class.new(
        name: :country, macro: :belongs_to, foreign_key: "country_id", klass: country_class
      )
      model.class.define_singleton_method(:reflect_on_association) do |n|
        reflection if n.to_sym == :country
      end

      # matched by association name and by foreign key alike
      %i[country country_id].each do |queried|
        result = resolve(model, queried)
        expect(result.as).to eq(:select)
        expect(result.name).to eq(:country_id)
        expect(result.label).to eq("Country")
        expect(result.required).to be(true)
        # lazy: a callable, resolved to [label, id] pairs via the name/title/label/to_s chain
        expect(result.choices.call).to eq([["Sweden", 1], ["Germany", 2]])
      end
    end
  end

  describe "column types (precedence 5)" do
    it "maps boolean/date/datetime columns" do
      model = build_model(
        :user, notify: nil, born_on: nil, starts_at: nil,
        validations: lambda {
          attribute :notify, :boolean
          attribute :born_on, :date
          attribute :starts_at, :datetime
        }
      )

      expect(resolve(model, :notify).as).to eq(:toggle)
      expect(resolve(model, :born_on).as).to eq(:date)
      expect(resolve(model, :starts_at).as).to eq(:datetime)
    end

    it "maps a text column to :textarea, beating the name map" do
      # ActiveModel has no :text type; ActiveRecord does. Duck-type the class.
      model = build_model(:user, email: nil, bio: nil)
      text_type = Struct.new(:type).new(:text)
      model.class.define_singleton_method(:type_for_attribute) { |_n| text_type }

      expect(resolve(model, :bio).as).to eq(:textarea)
      # the accepted degenerate case: a text column named email is a textarea
      expect(resolve(model, :email).as).to eq(:textarea)
    end

    it "maps integer and decimal columns to :number with a step" do
      model = build_model(
        :user, age: nil, price: nil,
        validations: lambda {
          attribute :age, :integer
          attribute :price, :decimal, scale: 2
        }
      )

      age = resolve(model, :age)
      expect(age.as).to eq(:number)
      expect(age.attributes[:step]).to eq(1)

      price = resolve(model, :price)
      expect(price.as).to eq(:number)
      expect(price.attributes[:step]).to eq(0.01)
    end

    it "lets the name map disambiguate string columns, but not non-string columns" do
      model = build_model(
        :user, email: nil, note: nil,
        validations: lambda {
          attribute :email, :string
          attribute :note, :string
        }
      )
      expect(resolve(model, :email).as).to eq(:email) # string column -> name map
      expect(resolve(model, :note).as).to eq(:text)
    end
  end

  describe "graceful degradation (precedence 6-7)" do
    it "falls back to the name map for untyped ActiveModel attributes" do
      model = build_model(:user, email: "a@b.c", bio: nil)

      expect(resolve(model, :email).as).to eq(:email)
      expect(resolve(model, :bio).as).to eq(:text)
    end

    it "falls back to the name map for plain objects and nil models" do
      plain = Struct.new(:email).new("a@b.c")

      expect(resolve(plain, :email).as).to eq(:email)
      expect(resolve(nil, :password).as).to eq(:password)
      expect(resolve(nil, :whatever).as).to eq(:text)
    end
  end

  describe "validator-derived attributes" do
    it "maps a length maximum to maxlength on text-like fields" do
      model = build_model(
        :user, handle: nil,
        validations: -> { validates :handle, length: { maximum: 30 } }
      )

      expect(resolve(model, :handle).attributes[:maxlength]).to eq(30)
    end

    it "keeps maxlength on the maximum, never an advisory recommended length" do
      model = build_model(
        :user, handle: nil,
        validations: -> { validates :handle, length: { maximum: 50, recommended: 32 } }
      )

      expect(resolve(model, :handle).attributes[:maxlength]).to eq(50)
    end

    it "maps numericality bounds to min/max on number fields only" do
      model = build_model(
        :user, age: nil, code: nil,
        validations: lambda {
          attribute :age, :integer
          validates :age, numericality: { greater_than_or_equal_to: 18, less_than_or_equal_to: 130 }
          validates :code, numericality: { greater_than_or_equal_to: 1 }
        }
      )

      age = resolve(model, :age)
      expect(age.attributes[:min]).to eq(18)
      expect(age.attributes[:max]).to eq(130)
      # :code renders as text (no column/name hint) -> numeric bounds don't apply
      expect(resolve(model, :code).attributes).not_to have_key(:min)
    end

    it "skips conditional validators" do
      model = build_model(
        :user, handle: nil,
        validations: -> { validates :handle, length: { maximum: 30 }, if: -> { false } }
      )

      expect(resolve(model, :handle).attributes).not_to have_key(:maxlength)
    end
  end

  describe "the infer_from_model kill-switch" do
    after { PhlexForms.reset_configuration! }

    it "disables structure/column/validator inference but keeps the name map" do
      PhlexForms.configure { |c| c.infer_from_model = false }
      model = build_model(
        :user, notify: nil, email: nil,
        validations: -> { attribute :notify, :boolean }
      )

      expect(resolve(model, :notify).as).to eq(:text)
      expect(resolve(model, :email).as).to eq(:email)
    end
  end
end
