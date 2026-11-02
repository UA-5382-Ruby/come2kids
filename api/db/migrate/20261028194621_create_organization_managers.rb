class CreateOrganizationManagers < ActiveRecord::Migration[8.0]
  def change
    create_table :organization_managers, id: false do |t|
      t.bigint :organization_id, null: false
      t.bigint :user_id, null: false
      t.references :added_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.datetime :added_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
      t.timestamps
    end

    execute "ALTER TABLE organization_managers ADD PRIMARY KEY (organization_id, user_id)"

    add_foreign_key :organization_managers, :organizations, on_delete: :cascade
    add_foreign_key :organization_managers, :users, on_delete: :cascade
    add_index :organization_managers, :user_id
  end
end
