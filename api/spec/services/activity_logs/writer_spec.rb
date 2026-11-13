# frozen_string_literal: true

require "rails_helper"

RSpec.describe ActivityLogs::Writer do
  describe ".call" do
    it "returns Success when the log is persisted" do
      log = instance_double(ActivityLog)
      allow(ActivityLog).to receive(:create!).and_return(log)

      result = described_class.call(action: "job.failed", result: "failure")

      expect(result).to be_success
      expect(result.value!).to eq(log)
      expect(ActivityLog).to have_received(:create!).with(
        hash_including(
          action: "job.failed",
          result: "failure",
          metadata: {},
        ),
      )
    end

    it "returns Failure and does not raise when persistence fails" do
      allow(ActivityLog).to receive(:create!).and_raise(StandardError, "mongo down")

      result = described_class.call(action: "job.failed")

      expect(result).to be_failure
      expect(result.failure).to be_a(StandardError)
      expect(result.failure.message).to eq("mongo down")
    end

    it "stringifies entity_id" do
      allow(ActivityLog).to receive(:create!).and_return(instance_double(ActivityLog))

      described_class.call(action: "job.failed", entity_id: 42)

      expect(ActivityLog).to have_received(:create!).with(hash_including(entity_id: "42"))
    end
  end
end
