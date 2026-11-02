class FixRoleIdsToConstants < ActiveRecord::Migration[8.0]
  class Role < ActiveRecord::Base
    self.table_name = :roles
  end

  def up
    Role.delete_all

    Role.create!(
      id: 1,
      key: 'owner',
      name_uk: 'Власник',
      name_en: 'Owner',
      created_at: Time.current,
      updated_at: Time.current
    )

    Role.create!(
      id: 2,
      key: 'manager',
      name_uk: 'Менеджер',
      name_en: 'Manager',
      created_at: Time.current,
      updated_at: Time.current
    )

    Role.connection.reset_pk_sequence!(:roles)
  end

  def down
  end
end
