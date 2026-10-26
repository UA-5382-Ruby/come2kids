# Environment variables

The API runs with sensible defaults in development and test, so **no variables are required
for local work**. The variables below override those defaults.

| Variable            | Used in        | Default                                   | Purpose                                                                 |
|---------------------|----------------|-------------------------------------------|-------------------------------------------------------------------------|
| `RAILS_ENV`         | all            | `development`                             | Rails environment (`development`, `test`, `production`).                |
| `DATABASE_URL`      | all            | unset – `config/database.yml` is used     | Full PostgreSQL URL, e.g. `postgres://user:pass@localhost:5432/api_development`. Takes precedence over `database.yml`. CI sets it. |
| `RAILS_MAX_THREADS` | all            | Puma: `3`, DB pool: `5`                   | Puma threads per worker and the DB connection pool size; set both together via this one variable. |
| `PORT`              | development    | `3000`                                    | Port for `bin/rails server`.                                            |
| `API_DATABASE_PASSWORD` | production | –                                         | Password for the production DB user (see `config/database.yml`).        |
| `RAILS_MASTER_KEY`  | production     | read from `config/master.key`             | Decrypts `config/credentials.yml.enc`. Never commit `master.key`.       |
| `MONGODB_URI`       | later          | –                                         | Connection string for the logs database (Mongoid), once it is added.    |

## Local database access

The default `config/database.yml` connects over the local Unix socket as the current OS user,
so after `sudo -u postgres createuser -s "$USER"` (see [setup.md](setup.md#postgresql)) no
username or password is needed.

If your PostgreSQL runs elsewhere (Docker, another host, password auth), export `DATABASE_URL`
instead of editing `database.yml`:

```bash
export DATABASE_URL=postgres://postgres:postgres@localhost:5432/api_development
```

## Secrets

- Never commit real secrets. `.env`, `.env*.local` and `config/master.key` are git-ignored.
- Ask a maintainer for `config/master.key` if you need production credentials.
