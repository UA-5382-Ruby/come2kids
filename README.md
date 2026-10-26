# Come2Kids

Monorepo for the Come2Kids project.

| Directory | Purpose |
|-----------|---------|
| [`api`](api) | Rails API application: models, controllers, policies, tests, generated Swagger docs |
| [`web`](web) | Placeholder for the future frontend (documentation only for now) |
| [`docs`](docs) | Setup instructions, environment variables, database notes, API summaries, user stories |

## Tooling

| Tool | Version | Managed by |
|------|---------|------------|
| Ruby | see [`.tool-versions`](.tool-versions) | ASDF |
| Node.js + npm | see [`.tool-versions`](.tool-versions) | ASDF |
| Rails | 8.1 (see `api/Gemfile.lock`) | Bundler |
| PostgreSQL | 15+ | system package / Homebrew |
| MongoDB | optional, needed later for logs | - |

Versions are pinned in a single place, [`.tool-versions`](.tool-versions). Do not change them
without telling the team.

## Quick start

Windows users: work inside **WSL2 (Ubuntu)**, see [docs/setup.md](docs/setup.md) for the full guide.

```bash
# 1. Install Ruby and Node.js with ASDF (versions come from .tool-versions)
asdf plugin add ruby
asdf plugin add nodejs
asdf install

# 2. Install PostgreSQL and create a role (details in docs/setup.md)
sudo -u postgres psql -c "CREATE ROLE come2kids WITH LOGIN CREATEDB PASSWORD 'come2kids'"

# 3. Install gems and set up the database
cd api
cp .env.example .env
bundle install
bin/rails db:setup

# 4. Run the server
bin/rails server
```

Production Docker files for the API: [`api/Dockerfile`](api/Dockerfile),
[`api/.dockerignore`](api/.dockerignore).

## Code style (Rubocop)

Style rules live in [`api/.rubocop.yml`](api/.rubocop.yml). Run from `api/`:

```bash
bundle exec rubocop        # check
bundle exec rubocop -a     # auto-fix safe offenses
```

Rubocop also runs in GitHub Actions on every pull request. A failing check blocks merging.

## Branch naming

```
issue-<number>/short-description
```

Examples: `issue-12/add-rubocop`, `issue-34/child-profile-model`.

More details in [docs/contributing.md](docs/contributing.md).

## Documentation

- [Environment setup](docs/setup.md)
- [Environment variables](docs/environment.md)
- [Contributing guide](docs/contributing.md)
