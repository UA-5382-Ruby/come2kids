# Database Notes

## Database engine

Come2Kids API uses PostgreSQL as its database management system.

Rails connects to the database through Active Record, which provides an interface for querying and modifying records using Ruby objects.

## Configuration

Database settings are typically maintained in:

`config/database.yml`

Review this file to confirm the database names and connection settings for development, test, and production.

## Migrations

Database structure changes should be managed through Rails migrations.

Common commands:

```bash
# Create the configured database
bin/rails db:create

# Apply pending migrations
bin/rails db:migrate

# Check the current schema version
bin/rails db:version

# Prepare the test database
RAILS_ENV=test bin/rails db:prepare
```

A schema version of `0` generally indicates that no migrations have been applied to that database.

## Schema management

The `db/schema.rb` file records the database structure represented by Rails migrations. Keep it synchronized with migration changes and include it in version control when the project uses the default schema format.

## Development and test data

Use seeds for reproducible development data when needed:

```bash
bin/rails db:seed
```

Avoid using real user data in local development or automated tests.

## Data integrity

- Use database constraints and indexes where appropriate.
- Define model validations for application-level input checks.
- Use foreign keys to enforce relational integrity when appropriate.
- Use transactions when multiple database operations must succeed or fail together.
- Never run destructive database commands against production without an explicit backup and recovery plan.
