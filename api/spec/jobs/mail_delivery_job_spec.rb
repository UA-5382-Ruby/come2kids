# frozen_string_literal: true

require "rails_helper"

RSpec.describe MailDeliveryJob, type: :job do
  include ActiveJob::TestHelper

  before do
    ActionMailer::Base.deliveries.clear

    stub_const(
      "SpecNotifyMailer",
      Class.new(ActionMailer::Base) do
        default from: "noreply@example.com"

        def hello(name)
          mail(to: "user@example.com", subject: "Hello #{name}", body: "Hi #{name}")
        end
      end,
    )
  end

  it "is queued on the mailers queue" do
    expect(described_class.new.queue_name).to eq("mailers")
  end

  it "uses email.delivery_failed as the Mongo action" do
    expect(described_class.new.failure_log_action).to eq("email.delivery_failed")
  end

  it "includes LogsFailuresToMongo" do
    expect(described_class.ancestors).to include(LogsFailuresToMongo)
  end

  it "delivers mail when Mails::Deliver succeeds" do
    expect {
      described_class.perform_now(
        "SpecNotifyMailer",
        "hello",
        "deliver_now",
        args: [ "Ada" ],
      )
    }.to change { ActionMailer::Base.deliveries.size }.by(1)
  end

  it "raises the Failure error from #perform (before Active Job rescue_from)" do
    failure = Dry::Monads::Result::Failure.new(StandardError.new("smtp down"))
    allow(Mails::Deliver).to receive(:call).and_return(failure)

    expect {
      described_class.new.perform(
        "SpecNotifyMailer",
        "hello",
        "deliver_now",
        args: [ "Ada" ],
      )
    }.to raise_error(StandardError, "smtp down")
  end
end
