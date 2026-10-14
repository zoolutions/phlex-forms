# frozen_string_literal: true

require "spec_helper"

describe Forms::Validations::Introspector do
  def model_class(&validations)
    Class.new do
      include ActiveModel::Model

      def self.name = "Widget"
      attr_accessor :title, :count, :kind, :terms, :password, :password_confirmation

      class_exec(&validations)
    end
  end

  def data_for(attribute, &validations)
    described_class.for(model_class(&validations)).data_attributes_for(attribute)
  end

  it "returns {} for an attribute with no supported validators" do
    data = data_for(:title) { validate :title, &:present? }
    expect(data).to eq({})
  end

  it "emits the presence controller and required value" do
    data = data_for(:title) { validates :title, presence: true }
    expect(data[:controller]).to eq("validations--presence")
    expect(data[:validations__presence_required_value]).to eq("true")
  end

  it "emits length min/max values" do
    data = data_for(:title) { validates :title, length: { minimum: 3, maximum: 60 } }
    expect(data[:validations__length_minimum_value]).to eq("3")
    expect(data[:validations__length_maximum_value]).to eq("60")
  end

  it "consolidates multiple validators into one space-joined controller list" do
    data = data_for(:title) { validates :title, presence: true, length: { maximum: 60 } }
    expect(data[:controller]).to eq("validations--presence validations--length")
  end

  it "converts a Ruby regex to a JS-compatible pattern (\\A/\\z -> ^/$)" do
    data = data_for(:title) { validates :title, format: { with: /\A[a-z]+\z/i } }
    expect(data[:validations__format_pattern_value]).to eq("^[a-z]+$")
    expect(data[:validations__format_flags_value]).to eq("i")
  end

  it "emits numericality bounds" do
    data = data_for(:count) { validates :count, numericality: { greater_than_or_equal_to: 0, only_integer: true } }
    expect(data[:validations__numericality_greater_than_or_equal_to_value]).to eq("0")
    expect(data[:validations__numericality_only_integer_value]).to eq("true")
  end

  it "emits inclusion list as JSON" do
    data = data_for(:kind) { validates :kind, inclusion: { in: %w[a b c] } }
    expect(data[:validations__inclusion_in_value]).to eq('["a","b","c"]')
  end

  it "emits the confirmation match attribute" do
    data = data_for(:password) { validates :password, confirmation: true }
    expect(data[:validations__confirmation_match_value]).to eq("password_confirmation")
  end

  it "skips validators with :if / :unless / :on (need server context)" do
    data = data_for(:title) { validates :title, presence: true, if: -> { true } }
    expect(data).to eq({})
  end

  it "returns a Null introspector for nil models" do
    expect(described_class.for(nil).data_attributes_for(:anything)).to eq({})
  end

  describe "message: option" do
    it "emits a String message verbatim, keeping %{count} for the browser" do
      data = data_for(:title) { validates :title, format: { with: /\A[a-z]*\z/, message: "lowercase only" } }
      expect(data[:validations__format_message_value]).to eq("lowercase only")
    end

    it "keeps %{count}-style placeholders in a String message" do
      data = data_for(:title) { validates :title, length: { maximum: 5, message: "max %{count}" } }
      expect(data[:validations__length_message_value]).to eq("max %{count}")
    end

    it "emits no message value when the validator declares none" do
      data = data_for(:title) { validates :title, format: { with: /\A[a-z]*\z/ } }
      expect(data).not_to have_key(:validations__format_message_value)
    end

    it "skips a Proc message (it needs a record)" do
      data = data_for(:title) { validates :title, presence: { message: ->(_o, _d) { "dynamic" } } }
      expect(data).not_to have_key(:validations__presence_message_value)
      expect(data[:validations__presence_required_value]).to eq("true")
    end

    it "emits a message value for every supported validator" do
      data = data_for(:kind) do
        validates :kind, presence: { message: "p" }, inclusion: { in: %w[a], message: "i" },
          exclusion: { in: %w[b], message: "e" }, numericality: { message: "n" },
          acceptance: { message: "a" }
      end
      expect(data).to include(
        validations__presence_message_value: "p", validations__inclusion_message_value: "i",
        validations__exclusion_message_value: "e", validations__numericality_message_value: "n",
        validations__acceptance_message_value: "a"
      )
      expect(data_for(:password) { validates :password, confirmation: { message: "c" } })
        .to include(validations__confirmation_message_value: "c")
    end

    it "emits the length per-case messages alongside message:" do
      data = data_for(:title) do
        validates :title, length: { minimum: 2, maximum: 5, is: 3, too_long: "long %{count}",
                                    too_short: "short %{count}", wrong_length: "wrong %{count}", message: "len" }
      end
      expect(data).to include(
        validations__length_too_long_message_value: "long %{count}",
        validations__length_too_short_message_value: "short %{count}",
        validations__length_wrong_length_message_value: "wrong %{count}",
        validations__length_message_value: "len"
      )
    end

    context "with a Symbol message" do
      around do |example|
        I18n.backend.store_translations(:en, activemodel: { errors: {
          models: { widget: { attributes: { title: { lowercase: "%{attribute} must be lowercase" } } } },
          messages: { lowercase: "generic lowercase", too_big: "at most %{count}" }
        } })
        example.run
      ensure
        I18n.backend.reload!
      end

      it "resolves the attribute-scoped translation, as errors.add would" do
        data = data_for(:title) { validates :title, format: { with: /\A[a-z]*\z/, message: :lowercase } }
        expect(data[:validations__format_message_value]).to eq("Title must be lowercase")
      end

      it "falls back to activemodel.errors.messages for another attribute" do
        data = data_for(:kind) { validates :kind, format: { with: /\A[a-z]*\z/, message: :lowercase } }
        expect(data[:validations__format_message_value]).to eq("generic lowercase")
      end

      it "leaves %{count} in place for the browser to fill" do
        data = data_for(:title) { validates :title, length: { maximum: 5, too_long: :too_big } }
        expect(data[:validations__length_too_long_message_value]).to eq("at most %{count}")
      end

      it "resolves in the current locale" do
        allow(I18n.config).to receive(:enforce_available_locales).and_return(false)
        I18n.backend.store_translations(:fr, activemodel: { errors: { messages: { lowercase: "minuscules" } } })
        data = I18n.with_locale(:fr) do
          data_for(:kind) { validates :kind, format: { with: /\A[a-z]*\z/, message: :lowercase } }
        end
        expect(data[:validations__format_message_value]).to eq("minuscules")
      end

      it "omits the value when the key resolves nowhere" do
        data = data_for(:title) { validates :title, format: { with: /\A[a-z]*\z/, message: :no_such_key } }
        expect(data).not_to have_key(:validations__format_message_value)
      end
    end
  end

  describe "paired with ManualRules" do
    it "produces the same data shape from an inline rules hash" do
      data = Forms::Validations::ManualRules.new(length: { maximum: 30 }, presence: true).data_attributes
      expect(data[:controller]).to include("validations--length")
      expect(data[:controller]).to include("validations--presence")
      expect(data[:validations__length_maximum_value]).to eq("30")
    end

    it "keeps message: from the rules hash" do
      data = Forms::Validations::ManualRules.new(
        format: { with: /\A[a-z]*\z/, message: "custom" },
        length: { maximum: 5, too_long: "max %{count}" },
        presence: { message: "needed" },
        confirmation: { message: "must match" }
      ).data_attributes
      expect(data).to include(
        validations__format_message_value: "custom",
        validations__length_too_long_message_value: "max %{count}",
        validations__presence_message_value: "needed",
        validations__confirmation_message_value: "must match"
      )
    end
  end
end
