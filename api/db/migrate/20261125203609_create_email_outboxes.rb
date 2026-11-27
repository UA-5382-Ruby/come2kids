# frozen_string_literal: true

class CreateEmailOutboxes < ActiveRecord::Migration[8.1]
  def change
    create_table :email_outboxes do |t|
      t.string :to_email, null: false
      t.string :template, null: false
      t.string :dedup_key, null: false
      t.jsonb :payload, null: false, default: {}
      t.string :status, null: false, default: 'pending'
      t.integer :attempts, null: false, default: 0
      t.text :last_error
      t.datetime :sent_at

      t.timestamps
    end

    add_index :email_outboxes, :dedup_key, unique: true
    add_index :email_outboxes, [ :status, :created_at ]
    add_check_constraint :email_outboxes, "status IN ('pending', 'sent', 'failed')", name: 'chk_email_outboxes_status'
  end
end
