class CreateRefreshTokens < ActiveRecord::Migration[8.0]
  def change
    create_table :refresh_tokens do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :token_hash, null: false
      t.datetime :expires_at, null: false
      t.datetime :revoked_at
      t.timestamps

      t.index :token_hash, unique: true
    end
  end
end
