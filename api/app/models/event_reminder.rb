# frozen_string_literal: true

# One reminder per event and user (US-12.3, FR-REM-2). The unique index prevents duplicates;
# rows are deleted when the event start time changes, so a new reminder goes out for the new date.
class EventReminder < ApplicationRecord
  belongs_to :event
  belongs_to :user

  validates :sent_at, presence: true
end
