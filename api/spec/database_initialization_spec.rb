require 'rails_helper'
require 'open3'
require 'cgi'

RSpec.describe 'Database Initialization' do
  TEST_DB_NAME = "come2kids_init_test_#{Process.pid}"
  DB_USERNAME = ENV['DB_USERNAME'].presence || 'postgres'
  DB_PASSWORD = ENV['DB_PASSWORD'].presence || 'postgres'
  DB_HOST = ENV['DB_HOST'].presence || 'localhost'
  DB_PORT = ENV['DB_PORT'].presence || '5432'
  DB_URL = "postgresql://#{DB_USERNAME}:#{DB_PASSWORD}@#{DB_HOST}:#{DB_PORT}/#{TEST_DB_NAME}"

  def run_cmd(cmd)
    Open3.capture3(cmd)
  end

  def run_with_db(cmd)
    original_url = ENV['DATABASE_URL']
    ENV['DATABASE_URL'] = DB_URL
    stdout, stderr, status = run_cmd(cmd)
    ENV['DATABASE_URL'] = original_url
    [ stdout, stderr, status ]
  end

  before(:all) do
    @original_url = ENV['DATABASE_URL']

    stdout, stderr, status = run_with_db("bundle exec rails db:create db:migrate 2>&1")
    unless status.success?
      raise "Database creation/migrations failed:\n#{stderr}\n#{stdout}"
    end
  end

  after(:all) do
    begin
      ActiveRecord::Base.establish_connection(Rails.env.to_sym)
      ActiveRecord::Base.connection.disconnect! if ActiveRecord::Base.connected?
    ensure
      _stdout, stderr, status = run_with_db("bundle exec rails db:drop 2>&1")
      ENV['DATABASE_URL'] = @original_url
      raise "Failed to drop temporary database #{TEST_DB_NAME}: #{stderr}" unless status.success?
    end
  end

  describe 'database creation and migrations from scratch' do
    it 'creates database and runs migrations successfully' do
      ActiveRecord::Base.establish_connection(DB_URL)
      tables = ActiveRecord::Base.connection.tables
      expect(tables).to include('schema_migrations')
      expect(tables).to include('roles')
    end

    it 'has no pending migrations' do
      stdout, _stderr, status = run_with_db("bundle exec rails db:migrate:status 2>&1")
      expect(status.success?).to be(true)
      expect(stdout).not_to match(/^\s*down\s/m)
    end
  end

  describe 'schema structure' do
    before(:all) do
      ActiveRecord::Base.establish_connection(DB_URL)
    end

    it 'has all expected tables' do
      expected_tables = %w[
        roles users organizations company_members
        organization_translations categories events event_translations
        ar_internal_metadata schema_migrations
      ]
      tables = ActiveRecord::Base.connection.tables
      expected_tables.each do |table|
        expect(tables).to include(table), "Missing table: #{table}"
      end
    end

    # email_tokens comes back with US-2.1; refresh tokens were removed (access tokens only).
    it 'does not have the email tokens table' do
      tables = ActiveRecord::Base.connection.tables
      expect(tables).not_to include('email_tokens')
    end

    it 'does not have the refresh tokens table' do
      tables = ActiveRecord::Base.connection.tables
      expect(tables).not_to include('refresh_tokens')
    end

    it 'does not have owner_id in organizations' do
      columns = ActiveRecord::Base.connection.columns(:organizations).map(&:name)
      expect(columns).not_to include('owner_id')
    end

    it 'has roles table with correct columns' do
      columns = ActiveRecord::Base.connection.columns(:roles).map(&:name).sort
      expect(columns).to eq(%w[created_at id key name_en name_uk updated_at].sort)
    end

    it 'has unique index on roles.key' do
      indexes = ActiveRecord::Base.connection.indexes(:roles)
      key_index = indexes.find { |idx| idx.columns == [ 'key' ] }
      expect(key_index).to be_present
      expect(key_index.unique).to be(true)
    end

    it 'has role_id NOT NULL in company_members' do
      columns = ActiveRecord::Base.connection.columns(:company_members)
      role_id = columns.find { |c| c.name == 'role_id' }
      expect(role_id).to be_present
      expect(role_id.null).to be(false)
    end

    it 'has FK from company_members.role_id to roles' do
      fks = ActiveRecord::Base.connection.foreign_keys(:company_members)
      role_fk = fks.find { |fk| fk.column == 'role_id' }
      expect(role_fk).to be_present
      expect(role_fk.to_table).to eq('roles')
    end

    it 'has composite PK on company_members' do
      pk = ActiveRecord::Base.connection.primary_key(:company_members)
      expect(pk).to eq([ 'organization_id', 'user_id' ])
    end

    it 'has partial unique index: one owner per organization' do
      indexes = ActiveRecord::Base.connection.indexes(:company_members)
      idx = indexes.find do |i|
        i.columns == [ 'organization_id' ] && i.where&.include?('role_id = 1')
      end
      expect(idx).to be_present
      expect(idx.unique).to be(true)
    end

    it 'has partial unique index: one organization per owner' do
      indexes = ActiveRecord::Base.connection.indexes(:company_members)
      idx = indexes.find do |i|
        i.columns == [ 'user_id' ] && i.where&.include?('role_id = 1')
      end
      expect(idx).to be_present
      expect(idx.unique).to be(true)
    end

    it 'has correct FK cascade on company_members' do
      fks = ActiveRecord::Base.connection.foreign_keys(:company_members)
      org_fk = fks.find { |fk| fk.column == 'organization_id' }
      user_fk = fks.find { |fk| fk.column == 'user_id' }
      expect(org_fk.on_delete).to eq(:cascade)
      expect(user_fk.on_delete).to eq(:cascade)
    end
  end

  describe 'seed data execution' do
    before(:all) do
      ActiveRecord::Base.establish_connection(DB_URL)
      stdout, stderr, status = run_with_db("bundle exec rails db:seed 2>&1")
      unless status.success?
        raise "Seeding failed:\n#{stderr}\n#{stdout}"
      end
    end

    it 'creates roles with fixed IDs' do
      owner = Role.find_by(key: 'owner')
      manager = Role.find_by(key: 'manager')
      expect(owner).to be_present
      expect(manager).to be_present
      expect(owner.id).to eq(1)
      expect(manager.id).to eq(2)
    end

    it 'creates all categories' do
      expect(Category.count).to eq(5)
      %w[education sports arts technology music].each do |slug|
        expect(Category.find_by(slug: slug)).to be_present
      end
    end

    it 'creates moderator account' do
      moderator = User.find_by(email: 'moderator@come2kids.dev')
      expect(moderator).to be_present
      expect(moderator.platform_role).to eq('moderator')
      expect(moderator.email_confirmed_at).to be_present
    end

    it 'creates demo organization with owner membership' do
      org = Organization.find_by(slug: 'demo-events')
      expect(org).to be_present
      owner_membership = org.company_members.find_by(role_id: Role.find_by(key: 'owner')&.id)
      expect(owner_membership).to be_present
      expect(owner_membership.user.email).to eq('owner@demo.com')
    end

    it 'creates demo events with translations' do
      org = Organization.find_by(slug: 'demo-events')
      expect(org).to be_present
      expect(org.events.count).to be >= 2
      org.events.each do |event|
        expect(event.event_translations.find_by(locale: 'uk')).to be_present
        expect(event.event_translations.find_by(locale: 'en')).to be_present
      end
    end

    it 'creates Faker-generated organizations with owners' do
      faker_orgs = Organization.where.not(slug: 'demo-events')
      expect(faker_orgs.count).to be >= 2
      faker_orgs.each do |org|
        expect(org.company_members.find_by(role_id: Role.find_by(key: 'owner')&.id)).to be_present
      end
    end

    it 'is idempotent' do
      stdout, stderr, status = run_with_db("bundle exec rails db:seed 2>&1")
      expect(status.success?).to be(true)
      expect(Role.count).to eq(2)
      expect(Category.count).to eq(5)
    end
  end

  describe 'cleanup verification' do
    it 'does not affect development database' do
      dev_db = Rails.configuration.database_configuration['development']['database']
      expect(dev_db).not_to eq(TEST_DB_NAME)
    end
  end
end
