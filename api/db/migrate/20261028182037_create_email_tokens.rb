class CreateEmailTokens < ActiveRecord::Migration[8.0]
  def change
    create_table :email_tokens do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :purpose, limit: 30, null: false
      t.string :token_hash, null: false
      t.datetime :expires_at, null: false
      t.datetime :used_at
      t.timestamps

      t.index :token_hash, unique: true
      t.check_constraint "purpose IN ('confirmation', 'reset')",
                         name: "chk_email_tokens_purpose"
    end
  end
end
