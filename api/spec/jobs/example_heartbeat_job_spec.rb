# frozen_string_literal: true

require "rails_helper"

RSpec.describe ExampleHeartbeatJob, type: :job do
  include ActiveJob::TestHelper

  it "is queued on the low queue" do
    expect(described_class.new.queue_name).to eq("low")
  end

  it "includes LogsFailuresToMongo" do
    expect(described_class.ancestors).to include(LogsFailuresToMongo)
  end

  it "runs successfully via the Result service" do
    expect { described_class.perform_now }.not_to raise_error
  end

  it "raises the Failure error from #perform (before Active Job rescue_from)" do
    failure = Dry::Monads::Result::Failure.new(StandardError.new("heartbeat failed"))
    allow(Jobs::ExampleHeartbeat).to receive(:call).and_return(failure)

    expect { described_class.new.perform }.to raise_error(StandardError, "heartbeat failed")
  end
end
