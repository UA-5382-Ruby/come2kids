# frozen_string_literal: true

class CreateEventReminders < ActiveRecord::Migration[8.1]
  def change
    create_table :event_reminders do |t|
      t.references :event, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.datetime :sent_at, null: false
    end

    add_index :event_reminders, %i[event_id user_id], unique: true
  end
end
