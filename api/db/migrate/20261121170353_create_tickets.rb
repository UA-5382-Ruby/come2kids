# frozen_string_literal: true

class CreateTickets < ActiveRecord::Migration[8.1]
  def change
    create_table :tickets do |t|
      t.references :order_item, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :event, null: false, foreign_key: true
      t.string :code, limit: 50, null: false
      t.string :qr_token, limit: 128, null: false
      t.string :status, limit: 20, null: false, default: "valid"
      t.datetime :issued_at, null: false
      t.datetime :used_at
      t.references :checked_in_by, foreign_key: { to_table: :users, on_delete: :nullify }

      t.timestamps
    end

    add_index :tickets, :code, unique: true
    add_index :tickets, :qr_token, unique: true
    add_index :tickets, :status

    add_check_constraint :tickets,
                         "status IN ('valid', 'used', 'cancelled')",
                         name: "chk_tickets_status"
  end
end
