# frozen_string_literal: true

# Moderator decisions on event revisions (US-6.2, FR-MOD-6) are logged against the revision.
class AllowEventRevisionsInModerationLogs < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :moderation_logs, name: 'chk_moderation_logs_entity_type'
    add_check_constraint :moderation_logs, "entity_type IN ('User', 'Organization', 'Event', 'EventRevision', 'Appeal')",
                         name: 'chk_moderation_logs_entity_type'
  end

  def down
    remove_check_constraint :moderation_logs, name: 'chk_moderation_logs_entity_type'
    add_check_constraint :moderation_logs, "entity_type IN ('User', 'Organization', 'Event', 'Appeal')",
                         name: 'chk_moderation_logs_entity_type'
  end
end
