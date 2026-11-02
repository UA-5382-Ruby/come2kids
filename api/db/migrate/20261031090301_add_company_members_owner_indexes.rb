class AddCompanyMembersOwnerIndexes < ActiveRecord::Migration[8.0]
  def change
    # NOTE: Один власник на організацію
    add_index :company_members, :organization_id,
              unique: true,
              where: "role_id = 1",
              name: "idx_company_members_one_owner_per_org"

    # NOTE: Користувач може володіти лише однією організацією
    add_index :company_members, :user_id,
              unique: true,
              where: "role_id = 1",
              name: "idx_company_members_one_org_per_user"
  end
end
