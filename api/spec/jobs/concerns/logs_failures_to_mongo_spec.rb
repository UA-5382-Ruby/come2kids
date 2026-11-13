# frozen_string_literal: true

require "rails_helper"

RSpec.describe LogsFailuresToMongo, type: :job do
  include ActiveJob::TestHelper

  # retry_on uses wait: :polynomially_longer — drain far-future scheduled retries.
  # When a block is given to retry_on, Rails does not re-raise after exhaustion.
  def perform_until_retries_exhausted
    perform_enqueued_jobs(at: 1.year.from_now) { yield }
  end

  before do
    stub_const(
      "FailingDemoJob",
      Class.new(ApplicationJob) do
        include LogsFailuresToMongo

        def perform
          raise StandardError, "always fails"
        end
      end,
    )
  end

  after { clear_enqueued_jobs }

  it "writes to Mongo after retries are exhausted" do
    success = Dry::Monads::Result::Success.new(true)
    allow(ActivityLogs::Writer).to receive(:call).and_return(success)

    expect {
      perform_until_retries_exhausted { FailingDemoJob.perform_later }
    }.not_to raise_error

    expect(ActivityLogs::Writer).to have_received(:call).with(
      hash_including(
        action: "job.failed",
        result: "failure",
        entity_type: "FailingDemoJob",
        metadata: hash_including(
          error_class: "StandardError",
          error_message: "always fails",
        ),
      ),
    )
  end

  it "uses failure_log_action when the job defines it" do
    stub_const(
      "FailingMailishJob",
      Class.new(ApplicationJob) do
        include LogsFailuresToMongo

        def failure_log_action
          "email.delivery_failed"
        end

        def perform
          raise StandardError, "mail boom"
        end
      end,
    )

    allow(ActivityLogs::Writer).to receive(:call).and_return(Dry::Monads::Result::Success.new(true))

    expect {
      perform_until_retries_exhausted { FailingMailishJob.perform_later }
    }.not_to raise_error

    expect(ActivityLogs::Writer).to have_received(:call).with(
      hash_including(action: "email.delivery_failed"),
    )
  end
end
