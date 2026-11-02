class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    enable_extension "citext"

    create_table :users do |t|
      t.citext :email, null: false
      t.string :password_digest, null: false
      t.string :first_name, limit: 100, null: false
      t.string :last_name, limit: 100, null: false
      t.string :phone, limit: 32
      t.date :birth_date
      t.string :avatar_url
      t.string :city, limit: 100
      t.string :preferred_locale, limit: 2, null: false, default: "uk"
      t.datetime :email_confirmed_at
      t.boolean :is_email_confirmed, null: false,
                as: "email_confirmed_at IS NOT NULL", stored: true  # generated column
      t.boolean :is_active, null: false, default: true
      t.datetime :blocked_at
      t.references :blocked_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.text :block_reason
      t.string :platform_role, limit: 20, null: false, default: "user"
      t.datetime :deleted_at
      t.timestamps

      t.index :email, unique: true
      t.check_constraint "preferred_locale IN ('uk', 'en')",
                         name: "chk_users_preferred_locale"
      t.check_constraint "platform_role IN ('user', 'moderator')",
                         name: "chk_users_platform_role"
    end
  end
end
