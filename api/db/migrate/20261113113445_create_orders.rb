# frozen_string_literal: true

class CreateOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :orders do |t|
      t.references :user, null: false, foreign_key: true
      t.references :event, null: false, foreign_key: true
      t.integer :total_amount, null: false
      t.string :currency, null: false, default: "980"
      t.string :status, null: false, default: "pending"
      t.string :idempotency_key
      t.datetime :reserved_until

      t.timestamps
    end
    add_index :orders, :idempotency_key, unique: true
  end
end
