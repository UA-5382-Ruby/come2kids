# frozen_string_literal: true

module Events
  # Deletes reminder rows for an event when its start time changes.
  # Does nothing until EPIC-12 creates event_reminders.
  class ClearReminders
    TABLE = 'event_reminders'

    def self.call(event)
      return unless ActiveRecord::Base.connection.data_source_exists?(TABLE)

      sql = ActiveRecord::Base.sanitize_sql_array([ "DELETE FROM #{TABLE} WHERE event_id = ?", event.id ])
      ActiveRecord::Base.connection.execute(sql)
    end
  end
end
