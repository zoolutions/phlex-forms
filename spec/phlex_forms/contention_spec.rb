# frozen_string_literal: true

# Tiers 1 and 2 of conformance-kit: resolving a theme, the lookup every field
# makes, returns the same object on every thread and every fiber.
RSpec.describe "PhlexForms::Theme.resolve under contention" do
  context "with the configured default" do
    let(:subject_call) { -> { PhlexForms::Theme.resolve(nil) } }

    it_behaves_like "thread-safe under contention", threads: 8, iterations: 50, consistent: :identical
    it_behaves_like "fiber-safe under an Async reactor", fibers: 8, iterations: 50, consistent: :identical
  end

  context "with a named theme" do
    let(:subject_call) { -> { PhlexForms::Theme.resolve(:plain) } }

    it_behaves_like "thread-safe under contention", threads: 8, iterations: 50, consistent: :identical
    it_behaves_like "fiber-safe under an Async reactor", fibers: 8, iterations: 50, consistent: :identical
  end
end
