class CreateOrganizationTranslations < ActiveRecord::Migration[8.0]
  def change
    create_table :organization_translations do |t|
      t.references :organization, null: false, foreign_key: { on_delete: :cascade }
      t.string :locale, limit: 2, null: false
      t.string :name, limit: 150, null: false
      t.text :description
      t.timestamps

      t.index [ :organization_id, :locale ], unique: true
      t.check_constraint "locale IN ('uk', 'en')", name: "chk_org_translations_locale"
    end
  end
end
