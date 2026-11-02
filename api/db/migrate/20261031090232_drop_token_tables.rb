class DropTokenTables < ActiveRecord::Migration[8.0]
  def change
    drop_table :refresh_tokens
    drop_table :email_tokens
  end
end
