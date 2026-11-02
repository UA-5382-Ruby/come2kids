class CreateCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :categories do |t|
      t.string :slug, limit: 60, null: false
      t.string :name_uk, limit: 100, null: false
      t.string :name_en, limit: 100, null: false
      t.integer :position
      t.timestamps

      t.index :slug, unique: true
    end
  end
end
