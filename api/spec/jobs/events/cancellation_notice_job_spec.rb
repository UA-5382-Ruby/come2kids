# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Events::CancellationNoticeJob, type: :job do
  it 'returns recipient ids and does not send mail' do
    event = create(:event)

    expect { described_class.perform_now(event.id) }.not_to change(ActionMailer::Base.deliveries, :count)
    expect(described_class.perform_now(event.id)).to eq([])
  end
end
