class CreateEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :events do |t|
      t.references :organization, null: false, foreign_key: { on_delete: :restrict }
      t.references :category, foreign_key: { on_delete: :restrict }
      t.references :created_by, null: false, foreign_key: { to_table: :users, on_delete: :restrict }
      t.datetime :start_at
      t.datetime :end_at
      t.string :time_zone, limit: 64, null: false, default: "Europe/Kyiv"
      t.string :location_type, limit: 10
      t.string :address
      t.string :city, limit: 100
      t.string :online_url
      t.string :banner_url
      t.string :status, limit: 20, null: false, default: "draft"
      t.text :rejection_reason
      t.datetime :submitted_at
      t.datetime :published_at
      t.references :reviewed_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.datetime :cancelled_at
      t.datetime :deleted_at
      t.timestamps

      t.index :start_at
      t.index :status
      t.index :city
      t.check_constraint "end_at > start_at", name: "chk_events_end_after_start"
      t.check_constraint "status IN ('draft', 'under_review', 'published', 'rejected', 'cancelled')",
                         name: "chk_events_status"
      t.check_constraint "location_type IS NULL OR location_type IN ('offline', 'online')",
                         name: "chk_events_location_type"
    end
  end
end
