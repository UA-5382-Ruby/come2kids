# frozen_string_literal: true

class CreateEventRevisions < ActiveRecord::Migration[8.1]
  STATUSES = "'under_review', 'approved', 'rejected', 'withdrawn'"

  def change
    create_table :event_revisions do |t|
      t.references :event, null: false, foreign_key: { on_delete: :cascade }
      t.references :submitted_by, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.jsonb :payload, null: false, default: {}
      t.string :status, limit: 20, null: false, default: 'under_review'
      t.references :reviewed_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.datetime :reviewed_at
      t.text :rejection_reason
      t.timestamps

      t.index :event_id, unique: true, where: "status = 'under_review'", name: 'idx_event_revisions_one_pending'
      t.check_constraint "status IN (#{STATUSES})", name: 'chk_event_revisions_status'
    end
  end
end
