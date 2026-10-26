# Environment variables

The Rails app reads its local configuration from `api/.env`. This file is created from the
committed template and is git-ignored:

```bash
cd api
cp .env.example .env
```

In development and test the file is loaded automatically by
[`dotenv-rails`](https://github.com/bkeepers/dotenv). Never commit `.env` or real secrets.

## Variables

| Variable | Default in `.env.example` | Description |
|----------|---------------------------|-------------|
| `DB_HOST` | `localhost` | PostgreSQL host |
| `DB_PORT` | `5432` | PostgreSQL port |
| `DB_USERNAME` | `come2kids` | PostgreSQL role |
| `DB_PASSWORD` | `come2kids` | Password of that role (local development only) |
| `DATABASE_URL` | not set | Optional full connection URL; overrides the `DB_*` variables |
| `RAILS_MAX_THREADS` | `5` | Puma threads and DB connection pool size |
| `COME2KIDS_DATABASE_PASSWORD` | not set | Production database password, set on the server only |

## Databases

| Environment | Database name |
|-------------|---------------|
| development | `come2kids_development` |
| test | `come2kids_test` |
| production | `come2kids_production` |

Connection settings are defined in [`api/config/database.yml`](../api/config/database.yml).
See [setup.md](setup.md#4-postgresql-and-the-development-database) for creating the PostgreSQL role.
