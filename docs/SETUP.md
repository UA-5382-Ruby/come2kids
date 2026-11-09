# Environment Setup Guide

This document provides a comprehensive, step-by-step guide to setting up the local development environment for the **Come2Kids** project.

---

### 1. Install Ruby

We highly recommend using a Ruby version manager such as **RVM** or **ASDF** to ensure consistency across the team.

* **Option A: Using RVM**
```bash
\curl -sSL https://get.rvm.io | bash -s stable
rvm install 3.3.0
rvm use 3.3.0 --default
```


* **Option B: Using ASDF**
```bash
asdf plugin add ruby
asdf install ruby 3.3.0
asdf global ruby 3.3.0
```



---

### 2. Install Rails

Install the latest stable version of Rails required for this project.

```bash
gem install rails
rails --version
```
---

### 3. Install PostgreSQL

PostgreSQL is the primary database for this project.

1. Download the installer from the official website: [postgresql.org/download](https://www.postgresql.org/download/)
2. Run the installer and keep the default settings.
3. **Remember the password** you set for the default `postgres` user.
4. Add the PostgreSQL binary directory to your system `PATH`:
* **Windows:** `C:\Program Files\PostgreSQL\18\bin`
* **macOS/Linux:** Usually added automatically by the installer.
---

### 4. Create the Development Database

Open your terminal and connect to PostgreSQL:

```bash
psql -U postgres
```

Inside the `psql` interactive prompt, execute the following commands to create the development database:

```sql
CREATE DATABASE come2kids_dev;
\q
```

---

### 5. Clone and Setup the Project

Once all prerequisites are met, clone the repository and initialize the application.

```bash
git clone https://github.com/YOUR_USERNAME/come2kids.git
cd come2kids/api
cp .env.example .env
bundle install
bin/rails db:setup
```

Start Redis (required for Sidekiq) and MongoDB locally, or use Docker Compose (section 6).

In one terminal start Sidekiq:

```bash
cd api
bundle exec sidekiq -C config/sidekiq.yml
# or: bin/jobs
```

In another terminal start the API:

```bash
cd api
bin/rails server
```

> **Note:** The application should now be running and accessible at [http://localhost:3000](http://localhost:3000).
> Sidekiq Web UI: [http://localhost:3000/sidekiq](http://localhost:3000/sidekiq) (set `SIDEKIQ_USERNAME` / `SIDEKIQ_PASSWORD` to protect it).

---

### 6. Docker Compose (recommended full stack)

Compose files + env templates (repo root):

- [`compose.yaml`](../compose.yaml) — production base (service topology only; values from env file)
- [`compose.override.yaml`](../compose.override.yaml) — local ports + Mailpit
- [`.env.example`](../.env.example) — local Compose defaults → copy to `.env`
- [`.env.production.example`](../.env.production.example) — production template → copy to `.env.production`

`api/.env.example` is for running Rails **without** Docker (localhost hosts). Root `.env*` is for Compose (service hostnames like `db`, `mongo`, `mailpit`).

From the repository root, **local development**:

```bash
cp .env.example .env
docker compose up -d --build
```

| Service | URL / port |
|---------|------------|
| API | http://localhost:3000 |
| Sidekiq Web | http://localhost:3000/sidekiq |
| Mailpit UI | http://localhost:8025 |
| Postgres | localhost:5432 |
| Redis | localhost:6379 |
| MongoDB | localhost:27017 |

**Production** (skip the override; use a real secrets file):

```bash
cp .env.production.example .env.production
# edit .env.production — replace every placeholder
docker compose -f compose.yaml --env-file .env.production up -d --build
```

Solid Cache / Solid Cable reuse the primary Postgres database in Compose
(`POSTGRES_CACHE_DB` / `POSTGRES_CABLE_DB` point at `POSTGRES_DB`).

Emails in development are caught by Mailpit (SMTP `localhost:1025`). Failed jobs and failed emails are retried by Sidekiq and logged to MongoDB (`activity_logs`).
