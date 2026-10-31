class CreateRoles < ActiveRecord::Migration[8.0]
  class Role < ActiveRecord::Base
    self.table_name = :roles
  end

  def up
    create_table :roles do |t|
      t.string :key, limit: 30, null: false
      t.string :name_uk, limit: 100, null: false
      t.string :name_en, limit: 100, null: false
      t.timestamps
    end

    add_index :roles, :key, unique: true

    Role.create!(id: 1, key: "owner",   name_uk: "Власник",  name_en: "Owner")
    Role.create!(id: 2, key: "manager", name_uk: "Менеджер", name_en: "Manager")

    Role.connection.reset_pk_sequence!(:roles)
  end

  def down
    drop_table :roles
  end
end
