class CreateEventTranslations < ActiveRecord::Migration[8.0]
  def change
    create_table :event_translations do |t|
      t.references :event, null: false, foreign_key: { on_delete: :cascade }
      t.string :locale, limit: 2, null: false
      t.string :title, limit: 200, null: false
      t.text :description
      t.timestamps

      t.index [ :event_id, :locale ], unique: true
      t.check_constraint "locale IN ('uk', 'en')", name: "chk_event_translations_locale"
    end
  end
end
