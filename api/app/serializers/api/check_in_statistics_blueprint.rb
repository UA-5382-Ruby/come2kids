# frozen_string_literal: true

module Api
  class CheckInStatisticsBlueprint < Blueprinter::Base
    field :issued
    field :checked_in
    field :remaining
    field :cancelled
    field :attendance_rate
    field :by_ticket_type
  end
end
