# Come2Kids Project

## Repository Structure

This repository is organized into three top-level areas:

- **api/** — The Rails API application, including models, controllers, policies, tests, and generated Swagger documentation.
- **web/** — Placeholder for the future frontend application. Contains documentation only at this stage.
- **docs/** — Project documentation: setup instructions, environment variables, database notes, API summaries, and user stories.

---

## Environment Setup

### Prerequisites

Before you begin, ensure you have the following tools installed:

#### 1. Ruby (via RVM or ASDF)

We recommend using **RVM** or **ASDF** to manage Ruby versions.

**Using RVM:**

    # Install RVM (if not already installed)
    \curl -sSL https://get.rvm.io | bash -s stable

    # Install Ruby 3.3.0
    rvm install 3.3.0
    rvm use 3.3.0 --default

**Using ASDF:**

    # Install ASDF (if not already installed)
    git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.13.1

    # Add Ruby plugin
    asdf plugin add ruby

    # Install Ruby 3.3.0
    asdf install ruby 3.3.0
    asdf global ruby 3.3.0

#### 2. Rails (Latest Stable Version)

    gem install rails

Verify installation:

    rails --version

#### 3. PostgreSQL (Main Database)

1. Download PostgreSQL from [official website](https://www.postgresql.org/download/).
2. Install and remember your password (default user: `postgres`).
3. Add PostgreSQL `bin` directory to your system PATH (on Windows: `C:\Program Files\PostgreSQL\18\bin`).
4. Create the development database:

    psql -U postgres

Inside psql:

    CREATE DATABASE come2kids_dev;
    \q

#### 4. Node.js + npm (Frontend Dependencies)

Download and install from [nodejs.org](https://nodejs.org/).

Verify:

    node --version
    npm --version

#### 5. Redis + Sidekiq (background jobs)

Required for Active Job. Install Redis locally or start the Compose stack (see below).

#### 6. MongoDB (activity / failure logs)

Used for append-only `activity_logs` (job and email failures today; full activity logging later).
Install MongoDB locally or use Docker Compose.

---

### Installation Steps

1. **Clone the repository:**

       git clone https://github.com/YOUR_USERNAME/come2kids.git
       cd come2kids

2. **Install Ruby dependencies:**

       cd api
       bundle install

3. **Setup the database:**

       rails db:setup

   This will create the database, load the schema, and seed initial data.

4. **Copy env template and run Sidekiq + the server:**

       cp .env.example .env
       bundle exec sidekiq -C config/sidekiq.yml   # terminal 1
       bin/rails server                            # terminal 2

   The API will be available at `http://localhost:3000`.

   Or start the full stack with Docker from the repo root:

       cp .env.example .env
       docker compose up -d --build
       # production:
       # cp .env.production.example .env.production
       # docker compose -f compose.yaml --env-file .env.production up -d --build

---

## Code Style & Linting

This project uses **Rubocop** to enforce consistent coding style across the team.

### Running Rubocop

    cd api
    bundle exec rubocop

### Auto-fix violations

    bundle exec rubocop -A

### Configuration

Rubocop configuration is stored in `.rubocop.yml` at the root of the `api/` directory.

---

## CI Integration

This project uses **GitHub Actions** to automatically run Rubocop on every Pull Request.

- The workflow is defined in `.github/workflows/ci.yml`.
- **Failing lint checks will block merging.** Ensure all Rubocop violations are resolved before requesting review.

---

## Branch Naming Convention

All branches must follow this format:

    issue-<number>/short-description

**Examples:**

- `issue-1/environment-setup`
- `issue-15/add-user-authentication`
- `issue-42/fix-login-bug`

---

## Pull Request Process

1. Create a branch from `main` using the naming convention above.
2. Make your changes.
3. Run `bundle exec rubocop` and fix any violations.
4. Push your branch to your fork.
5. Create a Pull Request to the `main` branch of the original repository.
6. Wait for CI checks (including Rubocop) to pass.
7. Request review from team members.

---

## Documentation

Detailed documentation is available in the `docs/` directory:

- [Environment Setup](docs/SETUP.md) — Detailed setup instructions
- [Environment Variables](docs/ENV_VARS.md) — Configuration and environment variables
- [Database Notes](docs/DATABASE.md) — Database schema and migration notes
- [API Summary](docs/API.md) — API endpoints and Swagger documentation
- [User Stories](docs/USER_STORIES.md) — Project requirements and user stories

---

## Troubleshooting

### Database connection issues

Ensure PostgreSQL is running and credentials in `api/config/database.yml` are correct.

### Rubocop violations after pulling

Run `bundle exec rubocop -A` to auto-fix style violations.

### Missing gems

Run `bundle install` in the `api/` directory.

---
