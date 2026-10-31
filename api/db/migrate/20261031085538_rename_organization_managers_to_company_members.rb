class RenameOrganizationManagersToCompanyMembers < ActiveRecord::Migration[8.0]
  def change
    rename_table :organization_managers, :company_members

    add_reference :company_members, :role, null: false,
                  foreign_key: { to_table: :roles, on_delete: :restrict }
  end
end
