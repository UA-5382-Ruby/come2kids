class CreateRoles < ActiveRecord::Migration[8.0]
  def change
    create_table :roles do |t|
      t.string :key, limit: 30, null: false
      t.string :name_uk, limit: 100, null: false
      t.string :name_en, limit: 100, null: false
      t.timestamps
    end

    add_index :roles, :key, unique: true
  end
end
