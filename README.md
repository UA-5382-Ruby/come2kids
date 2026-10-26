# come2kids

## Repository structure

| Path    | What's inside |
|---------|---------------|
| `api/`  | Rails API application: models, controllers, policies, tests, generated Swagger docs. |
| `web/`  | Placeholder for the future frontend application. Documentation only for now. |
| `docs/` | Project documentation: [setup](docs/setup.md), [environment variables](docs/environment.md), database notes, API summaries, user stories. |

## Environment setup

Detailed per-OS instructions (Windows/WSL2, macOS, Ubuntu) and troubleshooting are in
**[docs/setup.md](docs/setup.md)**.

**Required:** Ruby 4.0.9, Rails 8.1 (installed via Bundler), PostgreSQL, Node.js 24 LTS.
**Optional for now:** MongoDB. On Windows, work inside WSL2 Ubuntu.

### 1. Install Ruby

With **asdf** (reads `.tool-versions`, which also pins Node.js):

```bash
asdf plugin add ruby
asdf plugin add nodejs
asdf install
```

Or with **RVM** (reads `api/.ruby-version`):

```bash
rvm install 4.0.9
```

### 2. Install PostgreSQL and create a dev database user

```bash
sudo apt install -y postgresql postgresql-contrib libpq-dev    # macOS: brew install postgresql@17
sudo systemctl enable --now postgresql                         # macOS: brew services start postgresql@17
sudo -u postgres createuser -s "$USER"                         # not needed on macOS
```

### 3. Install gems

```bash
cd api
bundle install
```

### 4. Create the database

```bash
bin/rails db:setup      # creates api_development and api_test, loads the schema, runs seeds
```

## Code style: RuboCop

The rules are in [`api/.rubocop.yml`](api/.rubocop.yml) (RuboCop + `rubocop-rails`). CI runs the
same config on every pull request, so run it locally before you push:

```bash
cd api
bundle exec rubocop                     # check the whole app
bundle exec rubocop app/models/user.rb  # check one file
bundle exec rubocop -a                  # autocorrect safe offenses
```

Fix offenses rather than disabling cops. If a rule doesn't fit the project, propose a change to
`.rubocop.yml` in its own pull request.

## Branch naming

```
issue-<number>/short-description
```

`<number>` is the GitHub issue number; `short-description` is a few lowercase words in kebab-case.
Examples: `issue-1/environment-setup`, `issue-14/user-registration`.

## Pull requests and CI

- Open pull requests against `main`.
- GitHub Actions ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)) runs the `lint` job
  (`bundle exec rubocop`) on every pull request. Offenses show up as inline annotations.
- A pull request with a failing `lint` check can't be merged.

**One-time setup for repository admins**, needed so that failing lint blocks merging: go to
*Settings → Rules → Rulesets → New branch ruleset*:

1. Set **Enforcement status** to *Active*, and set **Target branches** to the default branch (`main`).
2. Enable **Require a pull request before merging**.
3. Enable **Require status checks to pass** and add the check **`lint`**. It appears in the list after
   the workflow has run once.
4. Save.
