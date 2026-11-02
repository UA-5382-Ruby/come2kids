class RemoveOwnerIdFromOrganizations < ActiveRecord::Migration[8.0]
  def change
    remove_reference :organizations, :owner, foreign_key: { to_table: :users, on_delete: :restrict }
  end
end
