# frozen_string_literal: true

class CreateEventMedia < ActiveRecord::Migration[8.1]
  def change
    create_table :event_media do |t|
      t.references :event, null: false, foreign_key: { on_delete: :cascade }
      t.string :kind, limit: 10, null: false
      t.integer :position, null: false, default: 0
      t.timestamps

      t.index %i[event_id kind position], name: 'index_event_media_on_event_kind_position'
      t.index :event_id, unique: true, where: "kind = 'banner'", name: 'idx_event_media_one_banner'
      t.check_constraint "kind IN ('banner', 'gallery')", name: 'chk_event_media_kind'
      t.check_constraint 'position >= 0', name: 'chk_event_media_position'
    end
  end
end
