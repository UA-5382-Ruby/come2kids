## Environment Setup for Backend (WSL / Ubuntu)

### 1. Install Ruby with RVM
```bash
\curl -sSL https://get.rvm.io | bash -s stable
source ~/.rvm/scripts/rvm
rvm install <version from .ruby-version>
rvm use <version> --default
```

### 2. Install PostgreSQL and create a dev database
```bash
sudo apt install -y postgresql postgresql-contrib libpq-dev
sudo service postgresql start
sudo -u postgres createuser -s $USER
```
The dev database is created automatically by `bundle exec rails db:setup`.

### 3. Install dependencies and set up the DB
```bash
cd api
bundle install
rails db:setup
```

## Code Style (Rubocop)
Run before every commit:
```bash
cd api
bundle exec rubocop        # check
bundle exec rubocop -a     # auto-fix safe issues
```
CI runs Rubocop on every pull request; PRs with violations cannot be merged.

## Branch Naming
Format: `issue-<number>/short-description`
Example: `issue-42/add-rubocop-config`