# frozen_string_literal: true

require "rails_helper"

RSpec.describe Mails::Deliver do
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


  describe ".call" do
    it "returns Success and delivers the message" do
      expect {
        result = described_class.call(
          mailer: "SpecNotifyMailer",
          mail_method: "hello",
          delivery_method: "deliver_now",
          args: [ "Ada" ],
        )
        expect(result).to be_success
      }.to change { ActionMailer::Base.deliveries.size }.by(1)

      expect(ActionMailer::Base.deliveries.last.subject).to eq("Hello Ada")
    end

    it "returns Failure when delivery raises" do
      delivery = instance_double(ActionMailer::MessageDelivery)
      allow(SpecNotifyMailer).to receive(:hello).with("Ada").and_return(delivery)
      allow(delivery).to receive(:deliver_now).and_raise(StandardError, "smtp down")

      result = described_class.call(
        mailer: "SpecNotifyMailer",
        mail_method: "hello",
        delivery_method: "deliver_now",
        args: [ "Ada" ],
      )

      expect(result).to be_failure
      expect(result.failure.message).to eq("smtp down")
    end


    it "returns Failure when the mailer constant is missing" do
      result = described_class.call(
        mailer: "MissingMailer",
        mail_method: "hello",
        delivery_method: "deliver_now",
        args: [],
      )

      expect(result).to be_failure
      expect(result.failure).to be_a(NameError)
    end
  end
end
