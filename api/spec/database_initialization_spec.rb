# frozen_string_literal: true

require 'rails_helper'
require 'open3'
require 'cgi'

class DbInitTempConnection < ActiveRecord::Base
  self.abstract_class = true
end

module DatabaseInitialization
  TEST_DB_NAME = "come2kids_init_test_#{Process.pid}".freeze
  DB_USERNAME = ENV['DB_USERNAME'].presence || 'postgres'
  DB_PASSWORD = ENV['DB_PASSWORD'].presence || 'postgres'
  DB_HOST = ENV['DB_HOST'].presence || 'localhost'
  DB_PORT = ENV['DB_PORT'].presence || '5432'
  DB_URL = "postgresql://#{DB_USERNAME}:#{DB_PASSWORD}@#{DB_HOST}:#{DB_PORT}/#{TEST_DB_NAME}".freeze

  class << self
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

    def prepare!
      return if @prepared

      stdout, stderr, status = run_with_db('bundle exec rails db:create db:migrate 2>&1')
      raise "Database creation/migrations failed:\n#{stderr}\n#{stdout}" unless status.success?

      DbInitTempConnection.establish_connection(
        adapter: 'postgresql',
        database: TEST_DB_NAME,
        username: DB_USERNAME,
        password: DB_PASSWORD,
        host: DB_HOST,
        port: DB_PORT
      )

      stdout, stderr, status = run_with_db('bundle exec rails db:seed 2>&1')
      raise "Seeding failed:\n#{stderr}\n#{stdout}" unless status.success?

      @prepared = true
    end

    def cleanup!
      DbInitTempConnection.connection.disconnect! if DbInitTempConnection.connected?
      _stdout, stderr, status = run_with_db('bundle exec rails db:drop 2>&1')
      raise "Failed to drop temporary database #{TEST_DB_NAME}: #{stderr}" unless status.success?
    end
  end
end

RSpec.configure do |config|
  config.before(:suite) { DatabaseInitialization.prepare! }
  config.after(:suite) { DatabaseInitialization.cleanup! }
end

RSpec.describe DatabaseInitialization do
  let(:conn) { DbInitTempConnection.connection }

  describe 'database creation and migrations' do
    it 'creates database and runs migrations successfully' do
      expect(conn.tables).to include('schema_migrations')
    end

    it 'creates application tables' do
      expect(conn.tables).to include('roles')
    end

    it 'has no pending migrations' do
      stdout, _stderr, status = described_class.run_with_db('bundle exec rails db:migrate:status 2>&1')
      expect(status.success?).to be(true)
    end

    it 'shows all migrations as applied' do
      stdout, _stderr, _status = described_class.run_with_db('bundle exec rails db:migrate:status 2>&1')
      expect(stdout).not_to match(/^\s*down\s/m)
    end
  end

  describe 'schema structure' do
    it 'has all expected tables' do
      expected_tables = %w[
        roles users organizations company_members
        organization_translations categories events event_translations
        ar_internal_metadata schema_migrations
        active_storage_blobs active_storage_attachments active_storage_variant_records
      ]
      expected_tables.each do |table|
        expect(conn.tables).to include(table)
      end
    end

    it 'does not have the email tokens table' do
      expect(conn.tables).not_to include('email_tokens')
    end

    it 'does not have the refresh tokens table' do
      expect(conn.tables).not_to include('refresh_tokens')
    end

    it 'does not have owner_id in organizations' do
      columns = conn.columns(:organizations).map(&:name)
      expect(columns).not_to include('owner_id')
    end

    it 'has roles table with correct columns' do
      columns = conn.columns(:roles).map(&:name).sort
      expect(columns).to eq(%w[created_at id key name_en name_uk updated_at].sort)
    end

    it 'has unique index on roles.key' do
      indexes = conn.indexes(:roles)
      key_index = indexes.find { |idx| idx.columns == [ 'key' ] }
      expect(key_index).to be_present
      expect(key_index.unique).to be(true)
    end

    it 'has role_id NOT NULL in company_members' do
      columns = conn.columns(:company_members)
      role_id = columns.find { |c| c.name == 'role_id' }
      expect(role_id).to be_present
      expect(role_id.null).to be(false)
    end

    it 'has FK from company_members.role_id to roles' do
      fks = conn.foreign_keys(:company_members)
      role_fk = fks.find { |fk| fk.column == 'role_id' }
      expect(role_fk).to be_present
      expect(role_fk.to_table).to eq('roles')
    end

    it 'has composite PK on company_members' do
      pk = conn.primary_key(:company_members)
      expect(pk).to eq([ 'organization_id', 'user_id' ])
    end

    it 'has partial unique index: one owner per organization' do
      indexes = conn.indexes(:company_members)
      idx = indexes.find do |i|
        i.columns == [ 'organization_id' ] && i.where&.include?('role_id = 1')
      end
      expect(idx).to be_present
      expect(idx.unique).to be(true)
    end

    it 'has partial unique index: one organization per owner' do
      indexes = conn.indexes(:company_members)
      idx = indexes.find do |i|
        i.columns == [ 'user_id' ] && i.where&.include?('role_id = 1')
      end
      expect(idx).to be_present
      expect(idx.unique).to be(true)
    end

    it 'has correct FK cascade on company_members for organization' do
      fks = conn.foreign_keys(:company_members)
      org_fk = fks.find { |fk| fk.column == 'organization_id' }
      expect(org_fk.on_delete).to eq(:cascade)
    end

    it 'has correct FK cascade on company_members for user' do
      fks = conn.foreign_keys(:company_members)
      user_fk = fks.find { |fk| fk.column == 'user_id' }
      expect(user_fk.on_delete).to eq(:cascade)
    end
  end

  describe 'seed data execution' do
    it 'creates owner role' do
      owner_id = conn.select_value("SELECT id FROM roles WHERE key='owner'")
      expect(owner_id).to eq(1)
    end

    it 'creates manager role' do
      manager_id = conn.select_value("SELECT id FROM roles WHERE key='manager'")
      expect(manager_id).to eq(2)
    end

    it 'creates all categories' do
      count = conn.select_value('SELECT COUNT(*) FROM categories')
      expect(count).to eq(5)
    end

    it 'creates education category' do
      expect(conn.select_value("SELECT id FROM categories WHERE slug='education'")).to be_present
    end

    it 'creates sports category' do
      expect(conn.select_value("SELECT id FROM categories WHERE slug='sports'")).to be_present
    end

    it 'creates arts category' do
      expect(conn.select_value("SELECT id FROM categories WHERE slug='arts'")).to be_present
    end

    it 'creates technology category' do
      expect(conn.select_value("SELECT id FROM categories WHERE slug='technology'")).to be_present
    end

    it 'creates music category' do
      expect(conn.select_value("SELECT id FROM categories WHERE slug='music'")).to be_present
    end

    it 'creates moderator account' do
      moderator_id = conn.select_value("SELECT id FROM users WHERE email='moderator@come2kids.dev'")
      expect(moderator_id).to be_present
    end

    it 'sets moderator platform_role' do
      role = conn.select_value("SELECT platform_role FROM users WHERE email='moderator@come2kids.dev'")
      expect(role).to eq('moderator')
    end

    it 'confirms moderator email' do
      confirmed = conn.select_value("SELECT email_confirmed_at FROM users WHERE email='moderator@come2kids.dev'")
      expect(confirmed).to be_present
    end

    it 'creates demo organization' do
      org_id = conn.select_value("SELECT id FROM organizations WHERE slug='demo-events'")
      expect(org_id).to be_present
    end

    it 'creates owner membership for demo organization' do
      org_id = conn.select_value("SELECT id FROM organizations WHERE slug='demo-events'")
      owner_id = conn.select_value("SELECT id FROM users WHERE email='owner@demo.com'")
      count = conn.select_value(
        "SELECT COUNT(*) FROM company_members WHERE organization_id=#{org_id} AND user_id=#{owner_id} AND role_id=1"
      )
      expect(count).to eq(1)
    end

    it 'creates demo events' do
      org_id = conn.select_value("SELECT id FROM organizations WHERE slug='demo-events'")
      count = conn.select_value("SELECT COUNT(*) FROM events WHERE organization_id=#{org_id}")
      expect(count).to be >= 2
    end

    it 'creates Ukrainian translations for demo events' do
      org_id = conn.select_value("SELECT id FROM organizations WHERE slug='demo-events'")
      count = conn.select_value(
        "SELECT COUNT(*) FROM event_translations et JOIN events e ON et.event_id=e.id WHERE e.organization_id=#{org_id} AND et.locale='uk'"
      )
      expect(count).to be >= 2
    end

    it 'creates English translations for demo events' do
      org_id = conn.select_value("SELECT id FROM organizations WHERE slug='demo-events'")
      count = conn.select_value(
        "SELECT COUNT(*) FROM event_translations et JOIN events e ON et.event_id=e.id WHERE e.organization_id=#{org_id} AND et.locale='en'"
      )
      expect(count).to be >= 2
    end

    it 'creates Faker-generated organizations' do
      count = conn.select_value("SELECT COUNT(*) FROM organizations WHERE slug != 'demo-events'")
      expect(count).to be >= 2
    end

    it 'creates owners for Faker-generated organizations' do
      faker_orgs = conn.select_values("SELECT id FROM organizations WHERE slug != 'demo-events'")
      faker_orgs.each do |org_id|
        count = conn.select_value(
          "SELECT COUNT(*) FROM company_members WHERE organization_id=#{org_id} AND role_id=1"
        )
        expect(count).to eq(1)
      end
    end

    it 'is idempotent' do
      _stdout, _stderr, status = described_class.run_with_db('bundle exec rails db:seed 2>&1')
      expect(status.success?).to be(true)
      expect(conn.select_value('SELECT COUNT(*) FROM roles')).to eq(2)
      expect(conn.select_value('SELECT COUNT(*) FROM categories')).to eq(5)
    end
  end

  describe 'cleanup verification' do
    it 'does not affect development database' do
      dev_db = Rails.configuration.database_configuration['development']['database']
      expect(dev_db).not_to eq(DatabaseInitialization::TEST_DB_NAME)
    end
  end
end
