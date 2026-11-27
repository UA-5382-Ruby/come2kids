# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Events::SendRemindersJob, type: :job do
  it 'runs the reminder service' do
    allow(Events::SendReminders).to receive(:call).and_return(0)

    described_class.perform_now

    expect(Events::SendReminders).to have_received(:call)
  end

  it 'is scheduled at least hourly' do
    schedule = YAML.safe_load(Rails.root.join('config/sidekiq_schedule.yml').read)

    expect(schedule.fetch('events_send_reminders')).to include('class' => 'Events::SendRemindersJob',
                                                               'cron' => '0 * * * *')
  end
end
