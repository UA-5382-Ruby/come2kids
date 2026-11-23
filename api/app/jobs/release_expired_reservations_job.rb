# frozen_string_literal: true

class ReleaseExpiredReservationsJob < ApplicationJob
  include LogsFailuresToMongo

  queue_as :default

  def perform
    result = ReleaseExpiredReservationsService.call
    return if result.success?

    raise result.failure
  end
end
