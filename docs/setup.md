# Environment setup

Goal: a working local Ruby + Rails + PostgreSQL environment, identical for everyone on the team.
Ruby and Node.js are installed with **ASDF**; versions are pinned in the root
[`.tool-versions`](../.tool-versions).

- [0. Windows: WSL2](#0-windows-wsl2)
- [1. System packages](#1-system-packages)
- [2. Install ASDF](#2-install-asdf)
- [3. Install Ruby and Node.js](#3-install-ruby-and-nodejs)
- [4. PostgreSQL and the development database](#4-postgresql-and-the-development-database)
- [5. Install gems and set up the database](#5-install-gems-and-set-up-the-database)
- [6. Check that everything works](#6-check-that-everything-works)
- [7. Optional: MongoDB](#7-optional-mongodb)
- [Troubleshooting](#troubleshooting)

## 0. Windows: WSL2

Do **not** run the project natively on Windows. Use WSL2 with Ubuntu and run all commands below
inside the Ubuntu terminal.

1. In PowerShell (as Administrator): `wsl --install -d Ubuntu`, then reboot and create a Linux user.
2. Clone the repository **inside the Linux filesystem** (`~/projects`), not under `/mnt/c`
   (it is much slower and breaks file watching):

   ```bash
   mkdir -p ~/projects && cd ~/projects
   git clone <repository-url> Come2Kids
   cd Come2Kids
   ```
3. Open the folder from WSL in your editor (`code .` for VS Code / `cursor .` for Cursor).

macOS and Linux users can skip this step.

## 1. System packages

Ubuntu / WSL:

```bash
sudo apt update
sudo apt install -y git curl build-essential autoconf bison pkg-config \
  libssl-dev libyaml-dev zlib1g-dev libreadline-dev libffi-dev libgmp-dev \
  libpq-dev postgresql postgresql-contrib
```

macOS (Homebrew):

```bash
brew install git openssl@3 libyaml gmp readline pkg-config libpq postgresql@17
```

## 2. Install ASDF

**Ubuntu / WSL (ASDF 0.14, git install):**

```bash
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.14.1
echo '. "$HOME/.asdf/asdf.sh"' >> ~/.bashrc
echo '. "$HOME/.asdf/completions/asdf.bash"' >> ~/.bashrc
source ~/.bashrc
```

(Zsh users: use `~/.zshrc` instead of `~/.bashrc`.)

**macOS (Homebrew, ASDF 0.16+):**

```bash
brew install asdf
echo 'export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

Check: `asdf --version`.

## 3. Install Ruby and Node.js

From the repository root:

```bash
asdf plugin add ruby
asdf plugin add nodejs
asdf install        # installs the versions from .tool-versions
```

Building Ruby takes a few minutes. Verify:

```bash
ruby -v     # must match the version in .tool-versions
node -v
npm -v
```

If `ruby -v` shows a different version, make sure you are inside the repository directory and that
ASDF is loaded in your shell (`asdf current`).

## 4. PostgreSQL and the development database

Start PostgreSQL:

```bash
# Ubuntu / WSL (systemd is not always enabled, `service` always works)
sudo service postgresql start

# macOS
brew services start postgresql@17
```

Create a development role (user). The credentials must match `api/.env` (see
[environment.md](environment.md)):

```bash
sudo -u postgres psql -c "CREATE ROLE come2kids WITH LOGIN CREATEDB PASSWORD 'come2kids'"
```

On macOS, `sudo -u postgres` is not needed: run `psql postgres -c "CREATE ROLE ..."` with the same SQL.

The role has `CREATEDB`, so Rails creates the databases `come2kids_development` and
`come2kids_test` itself in the next step. To create the development database manually instead:

```bash
sudo -u postgres createdb -O come2kids come2kids_development
```

Check the connection:

```bash
PGPASSWORD=come2kids psql -h localhost -U come2kids -d postgres -c "select version()"
```

The API also has a standard Rails production image (`api/Dockerfile`, `api/.dockerignore`)
for later deployment; local development uses ASDF and system Postgres as above.

## 5. Install gems and set up the database

```bash
cd api
cp .env.example .env     # local settings, never committed
bundle install
bin/rails db:setup       # creates the databases, loads the schema, runs seeds
```

## 6. Check that everything works

```bash
bin/rails server                 # http://localhost:3000, /up must return 200
bundle exec rubocop              # must report "no offenses detected"
```

## 7. Optional: MongoDB

MongoDB will be used later for logs. You do not need it now. When the time comes, install it
following the [official guide](https://www.mongodb.com/docs/manual/administration/install-on-linux/)
and update this document.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `ruby: command not found` after installing ASDF | Restart the terminal or `source ~/.bashrc`; check `asdf current` |
| `asdf install` fails while building Ruby | Install the packages from [step 1](#1-system-packages) and retry |
| `connection to server ... failed` | PostgreSQL is not running: `sudo service postgresql start` |
| `password authentication failed for user "come2kids"` | `DB_USERNAME`/`DB_PASSWORD` in `api/.env` do not match the role you created |
| `bad interpreter: /usr/bin/env: 'ruby\r'` | The repository was cloned with CRLF line endings; reclone inside WSL |
| `Gem::Ext::BuildError` for `pg` | `sudo apt install libpq-dev` and rerun `bundle install` |
