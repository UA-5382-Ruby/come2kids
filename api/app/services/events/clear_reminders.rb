# frozen_string_literal: true

module Events
  # Deletes reminder rows for an event when its start time changes (FR-REM-4), so the reminder job
  # sends a new reminder for the new date.
  class ClearReminders
    def self.call(event)
      EventReminder.where(event_id: event.id).delete_all
    end
  end
end
