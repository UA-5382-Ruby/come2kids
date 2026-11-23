# frozen_string_literal: true

# Appeals of blocked users and organizations (FR-APP-1..7).
# At most one open appeal per blocked user or organization (partial unique index).
class CreateAppeals < ActiveRecord::Migration[8.1]
  def change
    create_table :appeals do |t|
      t.string :target_type, limit: 20, null: false
      t.bigint :target_id, null: false
      t.references :submitted_by, null: false, foreign_key: { to_table: :users, on_delete: :cascade }
      t.text :message, null: false
      t.string :status, limit: 20, null: false, default: 'open'
      t.text :decision_reason
      t.references :reviewed_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.datetime :reviewed_at
      t.timestamps

      t.index %i[target_type target_id], unique: true, where: "status = 'open'",
                                         name: 'idx_appeals_one_open_per_target'
      t.index %i[target_type target_id created_at], name: 'index_appeals_on_target'
      t.index :status
      t.check_constraint "target_type IN ('User', 'Organization')", name: 'chk_appeals_target_type'
      t.check_constraint "status IN ('open', 'accepted', 'rejected')", name: 'chk_appeals_status'
      t.check_constraint 'char_length(message) BETWEEN 1 AND 2000', name: 'chk_appeals_message_length'
    end
  end
end
