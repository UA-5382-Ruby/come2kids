class CreateOrganizations < ActiveRecord::Migration[8.0]
  def change
    create_table :organizations do |t|
      t.references :owner, null: false, index: { unique: true },
                   foreign_key: { to_table: :users, on_delete: :restrict }
      t.citext :slug, null: false
      t.string :logo_url
      t.citext :contact_email, null: false
      t.string :phone, limit: 32
      t.string :website
      t.string :address
      t.string :city, limit: 100
      t.string :status, limit: 20, null: false, default: "pending_approval"
      t.text :rejection_reason
      t.datetime :approved_at
      t.references :approved_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.datetime :blocked_at
      t.references :blocked_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.text :block_reason
      t.datetime :deleted_at
      t.timestamps

      t.index :slug, unique: true, where: "deleted_at IS NULL",
              name: "index_organizations_on_slug_active"
      t.index :status
      t.check_constraint "status IN ('pending_approval', 'approved', 'rejected', 'blocked')",
                         name: "chk_organizations_status"
    end
  end
end
