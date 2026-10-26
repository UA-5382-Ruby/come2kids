# Development environment setup

The short version is in the [README](../README.md#environment-setup). This page has per-OS details
and troubleshooting.

| Tool       | Version          | Pinned in                              | Required          |
|------------|------------------|----------------------------------------|-------------------|
| Ruby       | 4.0.9            | `.tool-versions`, `api/.ruby-version`  | yes               |
| Rails      | 8.1.x            | `api/Gemfile.lock`                     | yes (via Bundler) |
| PostgreSQL | 16+              | –                                      | yes               |
| Node.js    | 24 LTS (24.22.1) | `.tool-versions`                       | yes               |
| MongoDB    | 8.x              | –                                      | optional for now  |

> When you bump Ruby, update both `.tool-versions` (read by asdf) and `api/.ruby-version`
> (read by RVM and CI).

---

## 1. Operating system

### Windows: use WSL2

RVM and asdf don't run on native Windows. Develop inside **WSL2 Ubuntu**:

```powershell
wsl --install -d Ubuntu      # elevated PowerShell, then reboot
wsl -d Ubuntu                # open the Ubuntu shell
```

- If Docker Desktop is installed, its `docker-desktop` distro may be the WSL default. Pass
  `-d Ubuntu`, or run `wsl --set-default Ubuntu`.
- Inside the Ubuntu shell the Windows launcher is called `wsl.exe`, not `wsl`.
- Forgot the Ubuntu (sudo) password? From PowerShell: `wsl -d Ubuntu -u root passwd <your-user>`.
- A repo on `/mnt/c` or `/mnt/d` is noticeably slower than one cloned into the Linux filesystem
  (e.g. `~/projects/come2kids`).
- **RubyMine:** *Settings → Languages & Frameworks → Ruby Interpreters → + → WSL*, then pick
  `Ubuntu` and `~/.asdf/installs/ruby/4.0.9/bin/ruby`.

Continue with the Ubuntu steps inside the WSL shell.

### Ubuntu / Debian (and WSL2)

System packages for compiling Ruby, the `pg` gem, and PostgreSQL. Run this as **one line**:

```bash
sudo apt update && sudo apt install -y build-essential autoconf git curl libssl-dev libyaml-dev zlib1g-dev libffi-dev libgmp-dev libreadline-dev rustc libpq-dev postgresql postgresql-contrib
```

### macOS

```bash
xcode-select --install
brew install openssl@3 libyaml gmp rust postgresql@17
export PATH="$(brew --prefix postgresql@17)/bin:$PATH"
```

---

## 2. Ruby and Node.js

Pick **one** version manager.

### Option A: asdf (manages Ruby and Node.js from `.tool-versions`)

```bash
# Install the asdf binary (Linux x86_64; on macOS: brew install asdf)
mkdir -p ~/.local/bin
curl -fsSL https://github.com/asdf-vm/asdf/releases/download/v0.20.2/asdf-v0.20.2-linux-amd64.tar.gz | tar -xz -C ~/.local/bin asdf

# Add to ~/.bashrc (or ~/.zshrc), then open a new shell
export PATH="$HOME/.local/bin:${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"

asdf plugin add ruby
asdf plugin add nodejs

cd come2kids
asdf install            # Ruby compiles in ~5–10 minutes
ruby -v                 # ruby 4.0.9
node -v && npm -v       # v24.22.1
```

### Option B: RVM

```bash
gpg --keyserver keyserver.ubuntu.com --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
curl -sSL https://get.rvm.io | bash -s stable
source ~/.rvm/scripts/rvm

rvm install 4.0.9
cd come2kids/api        # RVM picks up api/.ruby-version
ruby -v
```

RVM doesn't manage Node.js. Install it with [nvm](https://github.com/nvm-sh/nvm): `nvm install 24`.

### Rails

Rails is installed by `bundle install` from `api/Gemfile.lock`. A global `gem install rails` is
only needed if you want to run the `rails new` generator outside the project.

---

## 3. PostgreSQL

Start the server and create a database role named after your OS user. Rails then connects over the
local socket without a password:

```bash
sudo systemctl enable --now postgresql     # without systemd: sudo service postgresql start
sudo -u postgres createuser -s "$USER"
psql -d postgres -c 'select version();'    # should print the server version
```

On macOS: `brew services start postgresql@17`. Your user already owns the cluster, so skip `createuser`.

Then, from `api/`:

```bash
bundle install
bin/rails db:setup      # creates api_development and api_test, loads db/schema.rb, runs db/seeds.rb
```

To use a password-protected or Dockerized PostgreSQL, see
[environment.md](environment.md#local-database-access).

---

## 4. MongoDB (optional for now)

MongoDB will store logs later. You don't need it yet. When you do, the simplest option is Docker:

```bash
docker run -d --name come2kids-mongo -p 127.0.0.1:27017:27017 -v come2kids-mongo:/data/db mongo:8
```

Native packages: <https://www.mongodb.com/docs/manual/administration/install-on-linux/>.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `Unable to locate package` / `command not found` after pasting the apt command | The paste broke the line; run the apt command as one line. |
| `Can't find the 'libpq-fe.h' header` while installing `pg` | `sudo apt install libpq-dev` (macOS: `brew install libpq`) |
| `FATAL: role "<you>" does not exist` | `sudo -u postgres createuser -s "$USER"` |
| `connection to server on socket ... failed` | PostgreSQL isn't running: `sudo systemctl start postgresql` |
| `yaml.h not found` / `psych` errors while compiling Ruby | `sudo apt install libyaml-dev`, then `asdf install` again |
| `ruby: command not found` after `asdf install` | The asdf shims directory isn't on `PATH`; check your shell rc and open a new shell |
| `/usr/bin/env: 'ruby\r': No such file or directory` | Windows line endings. The repo's `.gitattributes` forces LF; for a checkout made before it existed, run `git rm --cached -r . && git reset --hard` (commit your work first) |
