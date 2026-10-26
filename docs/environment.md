# Environment variables

The API runs with sensible defaults in development and test, so **no variables are required
for local work**. The variables below override those defaults.

| Variable            | Used in        | Default                                   | Purpose                                                                 |
|---------------------|----------------|-------------------------------------------|-------------------------------------------------------------------------|
| `RAILS_ENV`         | all            | `development`                             | Rails environment (`development`, `test`, `production`).                |
| `DATABASE_URL`      | all            | unset – `config/database.yml` is used     | Full PostgreSQL URL, e.g. `postgres://user:pass@localhost:5432/api_development`. Takes precedence over `database.yml`. CI sets it. |
| `RAILS_MAX_THREADS` | all            | Puma: `3`, DB pool: `5`                   | Puma threads per worker and the DB connection pool size; set both together via this one variable. |
| `PORT`              | development    | `3000`                                    | Port for `bin/rails server`.                                            |
| `CACHE_DATABASE_URL`, `QUEUE_DATABASE_URL`, `CABLE_DATABASE_URL` | production | – | URLs of the Solid Cache, Solid Queue and Solid Cable databases. `DATABASE_URL` only configures the primary database. See [Production deploy](#production-deploy-kamal). |
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
export DATABASE_URL="postgres://postgres:YOUR_PASSWORD@localhost:5432/api_development"
```

Replace `YOUR_PASSWORD` with your own password. Keep the real value out of the repository: put the
`export` line in your shell profile (`~/.bashrc` or `~/.zshrc`). The app doesn't load `.env` files.

## Production deploy (Kamal)

`bin/kamal deploy` passes the database connection to the container as secrets
(`env.secret` in `api/config/deploy.yml`, values in `api/.kamal/secrets`). The image runs
`bin/rails db:prepare` before starting the server, so all four URLs must be set, or the container
stops before the app boots. Export them in the shell you deploy from (or load them from a password
manager in `.kamal/secrets`):

```bash
export DATABASE_URL="postgres://api:YOUR_PASSWORD@DB_HOST:5432/api_production"
export CACHE_DATABASE_URL="postgres://api:YOUR_PASSWORD@DB_HOST:5432/api_production_cache"
export QUEUE_DATABASE_URL="postgres://api:YOUR_PASSWORD@DB_HOST:5432/api_production_queue"
export CABLE_DATABASE_URL="postgres://api:YOUR_PASSWORD@DB_HOST:5432/api_production_cable"
```

**Before the first real deploy, turn on HTTPS.** `api/config/deploy.yml` still uses placeholder hosts, and
TLS termination isn't configured yet: the Kamal proxy's `ssl: true` is commented out, and so are
`config.assume_ssl`, `config.force_ssl` and the `/up` redirect exception in
`api/config/environments/production.rb`. Once TLS terminates in front of the app (Kamal proxy with
`ssl: true` and a real `host`, or a load balancer), uncomment those three settings so all traffic uses
HTTPS and cookies are marked secure.

## Secrets

- Never commit real secrets. `.env`, `.env*.local` and `config/master.key` are git-ignored.
- Ask a maintainer for `config/master.key` if you need production credentials.
