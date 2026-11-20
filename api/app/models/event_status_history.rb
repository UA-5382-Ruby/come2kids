# frozen_string_literal: true

class EventStatusHistory < ApplicationRecord
  belongs_to :event
  belongs_to :changed_by, class_name: 'User', optional: true

  validates :to_status, inclusion: { in: Event::STATUSES }
  validates :from_status, inclusion: { in: Event::STATUSES }, allow_nil: true
  validates :changed_at, presence: true
end
