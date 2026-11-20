# frozen_string_literal: true

class AddEventStatusHistory < ActiveRecord::Migration[8.1]
  STATUSES = "'draft', 'under_review', 'published', 'rejected', 'cancelled', 'cancelled_by_organizer'"

  def change
    change_column :events, :status, :string, limit: 30, null: false, default: 'draft'
    remove_check_constraint :events, name: 'chk_events_status'
    add_check_constraint :events, "status IN (#{STATUSES})", name: 'chk_events_status'

    create_table :event_status_histories do |t|
      t.references :event, null: false, foreign_key: { on_delete: :cascade }
      t.string :from_status, limit: 30
      t.string :to_status, limit: 30, null: false
      t.references :changed_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.text :reason
      t.string :error_code, limit: 50
      t.datetime :changed_at, null: false

      t.index %i[event_id changed_at]
      t.check_constraint "from_status IS NULL OR from_status IN (#{STATUSES})",
                         name: 'chk_event_status_histories_from_status'
      t.check_constraint "to_status IN (#{STATUSES})", name: 'chk_event_status_histories_to_status'
    end
  end
end
