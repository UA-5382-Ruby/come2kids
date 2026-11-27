# frozen_string_literal: true

class CreateSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :subscriptions do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :target_type, limit: 20, null: false
      t.bigint :target_id, null: false

      t.timestamps
    end

    add_index :subscriptions, %i[user_id target_type target_id], unique: true
    add_index :subscriptions, %i[target_type target_id]
    add_check_constraint :subscriptions, "target_type IN ('Event', 'Organization')",
                         name: 'chk_subscriptions_target_type'
  end
end
