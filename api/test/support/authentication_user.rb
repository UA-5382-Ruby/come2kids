# US-2.1's User model and users migration are not present on this branch.
# Supply their authentication contract only in tests until that dependency lands.
unless defined?(User)
  raise "Authentication fixtures require the test environment" unless Rails.env.test?

  class User < ApplicationRecord
    has_secure_password
  end

  ActiveRecord::Migration.suppress_messages do
    connection = ActiveRecord::Base.connection
    unless connection.table_exists?(:users)
      connection.create_table :users do |t|
        t.string :email, null: false
        t.string :password_digest, null: false
        t.boolean :is_active, default: true, null: false
        t.boolean :is_email_confirmed, default: true, null: false
        t.datetime :blocked_at
        t.string :block_reason
        t.datetime :deleted_at
        t.timestamps
      end
      connection.add_index :users, :email, unique: true
    end

    # Exercise the real refresh-token migration against the fixture's user table.
    ActiveRecord::Base.connection_pool.migration_context.migrate
  end

  # The checked-in schema is empty on this branch; the migrations above prepared
  # the test database. Do not replace it with that empty schema on test boot.
  ActiveRecord.maintain_test_schema = false
end
