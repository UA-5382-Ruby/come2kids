# frozen_string_literal: true

require "rails_helper"

RSpec.describe Jobs::ExampleHeartbeat do
  describe ".call" do
    it "returns Success with a timestamp" do
      result = described_class.call

      expect(result).to be_success
      expect(result.value!).to include(:timestamp)
      expect(result.value![:timestamp]).to match(/\d{4}-\d{2}-\d{2}T/)
    end

    it "returns Failure when logging blows up" do
      allow(Rails.logger).to receive(:info).and_raise(StandardError, "boom")

      result = described_class.call

      expect(result).to be_failure
      expect(result.failure.message).to eq("boom")
    end
  end
end
