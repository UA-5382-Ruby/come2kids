# frozen_string_literal: true

# Audit trail of every moderation decision (FR-MOD-3, FR-MOD-7, FR-APP-7).
# Rows are append-only; moderator_id is null for actions of the appellant (appeal submitted).
class CreateModerationLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :moderation_logs do |t|
      t.string :entity_type, limit: 30, null: false
      t.bigint :entity_id, null: false
      t.references :moderator, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :decision, limit: 30, null: false
      t.text :reason
      t.datetime :created_at, null: false, default: -> { 'CURRENT_TIMESTAMP' }

      t.index %i[entity_type entity_id created_at], name: 'index_moderation_logs_on_entity'
      t.index :created_at
      t.check_constraint "entity_type IN ('User', 'Organization', 'Event', 'Appeal')",
                         name: 'chk_moderation_logs_entity_type'
      t.check_constraint "decision IN ('approved', 'rejected', 'blocked', 'unblocked', " \
                         "'appeal_submitted', 'appeal_accepted', 'appeal_rejected')",
                         name: 'chk_moderation_logs_decision'
    end
  end
end
