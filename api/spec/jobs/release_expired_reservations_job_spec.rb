# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReleaseExpiredReservationsJob do
  include Dry::Monads[:result]

  describe '#perform' do
    it 'calls ReleaseExpiredReservationsService and succeeds on Success result' do
      allow(ReleaseExpiredReservationsService).to receive(:call).and_return(Success(2))

      expect { described_class.new.perform }.not_to raise_error
      expect(ReleaseExpiredReservationsService).to have_received(:call)
    end

    it 'raises the failure error when service returns Failure' do
      error = StandardError.new('db timeout')
      allow(ReleaseExpiredReservationsService).to receive(:call).and_return(Failure(error))

      expect { described_class.new.perform }.to raise_error(StandardError, 'db timeout')
    end
  end
end
