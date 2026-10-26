# Come2kids
**An event discovery and ticketing platform.**

Come2Kids is a web application designed to help users discover events, explore event details, and purchase tickets online. The platform aims to provide a convenient experience for finding concerts, festivals, theatre performances, and other events.

The project consists of a React frontend and a Ruby on Rails backend, with PostgreSQL used for persistent data storage.

## Table of Contents

- [Features](#features)
- [Technology Stack](#technology-stack)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
    - [Install Ruby](#1-install-ruby)
    - [Install PostgreSQL](#2-install-postgresql)
    - [Install dependencies](#3-install-ruby-dependencies)
    - [Configure the database](#4-configure-the-development-database)
    - [Set up the database](#5-run-database-setup)
    - [Install frontend dependencies](#6-install-frontend-dependencies)
- [Environment Configuration](#environment-configuration)
- [Database Setup](#database-setup)
- [Running the Application](#running-the-application)
- [Testing](#testing)
- [Code Quality](#code-quality)
- [Contributing](#contributing)
- [Development Guidelines](#development-guidelines)
- [License](#license)

## Features

The platform is intended to support the following functionality:

- **Event Discovery** — browse upcoming events and explore available categories.
- **Event Search and Filtering** — find events by name, date, category, or location.
- **Event Details** — view descriptions, venues, schedules, and ticket prices.
- **Ticket Selection** — choose ticket types and quantities.
- **Online Checkout** — submit orders and complete purchases through a secure payment integration.
- **User Accounts** — manage user profiles and access order history, where supported.
- **Order Management** — view purchase details and ticket information.

Feature availability depends on the current implementation.

## Technology Stack

| Component | Technology |
|---|---|
| Frontend | React, TypeScript |
| Frontend tooling | Vite |
| Backend | Ruby on Rails |
| Database | PostgreSQL |
| Backend testing | RSpec |
| Version control | Git |
| CI/CD | GitHub Actions |
| Lint | Rubocop |
| ORM | ActiveRecord |

Additional libraries and services may be introduced as the project evolves.

## Project Structure

The repository may be organized as follows:

```text
come2kids/
├── web/             # React application
│   ├── src/
│   ├── public/
│   ├── package.json
│   └── README.md
├── api/                  # Ruby on Rails API
│   ├── app/
│   ├── config/
│   ├── db/
│   ├── spec/
│   ├── Gemfile
│   └── README.md
├── docs/                 # Project documentation
├── .gitignore
└── README.md
```

This is a suggested layout. Adapt it to the actual repository structure.

## Prerequisites

Install the following tools before starting development:

- Git
- Ruby and RubyGems
- Bundler
- PostgreSQL
- Node.js and npm

Use the Ruby and Node.js versions specified by the project configuration, if available.

Verify your installations:

```bash
ruby --version
gem --version
bundle --version
psql --version
node --version
npm --version
```

## Getting Started

The commands below assume the Rails API is in `api/` and the React application is in `frontend/`. If your local repository uses different directory names, adjust the paths accordingly.

### 1. Install Ruby

Use **either RVM or ASDF** to install and manage Ruby. You do not need both.

#### Option A: RVM

RVM is primarily intended for macOS and Linux. Install it by following the official instructions at [rvm.io](https://rvm.io/). Then install the Ruby version required by the project:

```bash
rvm install <ruby-version>
rvm use <ruby-version>
gem install bundler
```

Replace `<ruby-version>` with the version declared in `.ruby-version`, if the repository has that file.

#### Option B: ASDF

Install ASDF using the instructions for your operating system in the [ASDF documentation](https://asdf-vm.com/). Add the Ruby plugin, then install the project's Ruby version:

```bash
asdf plugin add ruby
asdf install ruby <ruby-version>
asdf set ruby <ruby-version>
gem install bundler
```

Replace `<ruby-version>` with the version declared in `.ruby-version`. ASDF plugin setup can differ depending on the ASDF version; follow its current documentation if the commands differ.

If the repository does not specify a Ruby version, agree on one with the project maintainers before installing it.

### 2. Install PostgreSQL

Install PostgreSQL for your operating system using the [official PostgreSQL downloads](https://www.postgresql.org/download/).

Make sure the PostgreSQL server is running and that the `psql` command is available in your terminal. Create a development database and a database role with permission to access it, or use an existing local PostgreSQL role configured for your environment.

For example, if your local PostgreSQL setup provides the `createdb` utility and your current OS user has permission to create databases:

```bash
createdb come2kids
```

If the database role or permissions are not configured, use the PostgreSQL administration tools or `psql` to create a role and grant it the required privileges. Do not use production credentials for local development.

### 3. Install Ruby dependencies

From the repository root, navigate to the Rails API directory:

```bash
cd api
bundle install
```

Bundler installs the gems declared in the API's `Gemfile` and records resolved dependencies in `Gemfile.lock`.

### 4. Configure the development database

Review `config/database.yml` and any environment variables used by the application. Ensure the development configuration points to the local PostgreSQL instance and the database name you created.

For example, a configuration may use a database URL such as:

```env
DATABASE_URL=postgresql://localhost/come2kids_development
```

This is only an example. Use the connection format, username, password, host, and port expected by the project's actual configuration. If Rails uses a different database name in `config/database.yml`, keep the configuration and created database consistent.

### 5. Run database setup

From the Rails API directory, run:

```bash
bin/rails db:setup
```

This Rails task creates the databases, loads the schema, and loads seed data where applicable. It is intended for initial setup; if the database already exists, Rails may report that it already exists. For an existing development database, use the project's normal migration workflow, such as `bin/rails db:migrate`.

To check the current schema version:

```bash
bin/rails db:version
```

### 6. RuboCop usage

Команда для перевірки стилю Ruby-коду з директорії Rails API:

```
cd api
bundle exec rubocop
```

### 7. Branch naming convention

Формат назви гілок:

```
issue-<number>/short-description
```

Приклади:

```
issue-12/event-search
issue-34/add-ticket-checkout
issue-57/fix-user-authentication
```

### 8. Install frontend dependencies

Open a separate terminal and navigate to the React application directory:

```bash
cd frontend
npm install
```

If the repository uses a different package manager, follow the existing lockfile and project configuration.

## Environment Configuration

Configure the environment variables required by each application.

### Backend

Rails database settings are commonly defined in `config/database.yml`. If the application uses environment variables or Rails credentials, configure the required values according to the existing implementation.

Example PostgreSQL connection string:

```env
DATABASE_URL=postgresql://localhost/come2kids
```

This is an example only; use the actual database name, username, password, host, and port required by your environment.

### Frontend

Create a `.env` file in the frontend directory if required:

```env
VITE_API_BASE_URL=http://localhost:3000
```

The variable above assumes that the Rails API runs on port `3000`.

**Security guidelines:**

- Never commit real credentials, tokens, or private keys.
- Do not expose database credentials or payment provider secrets to the frontend.
- Keep local environment files out of version control.
- Provide an `.env.example` file containing placeholders for required configuration values.

## Database Setup

Come2Kids uses PostgreSQL for persistent data storage.

From the backend directory, create and migrate the development database:

```bash
bin/rails db:create
bin/rails db:migrate
```

To inspect the current database version:

```bash
bin/rails db:version
```

To load seed data, if seeds are defined:

```bash
bin/rails db:seed
```

Database schema changes must be introduced through Rails migrations.

Do not commit real user data or production database credentials. Avoid destructive database commands against shared or production environments.

## Running the Application

### Start the backend

From the Rails API directory:

```bash
bin/rails server
```

By default, the server is available at:

`http://localhost:3000`

### Start the frontend

From the frontend directory:

```bash
npm run dev
```

Vite prints the local development URL in the terminal, commonly:

`http://localhost:5173`

Keep both development servers running while working on frontend features that require the API.

If the frontend and backend run on different origins, configure the appropriate CORS policy in Rails.

## Testing

### Backend tests

The backend uses RSpec.

Run the test suite from the API directory:

```bash
bundle exec rspec
```

When adding backend functionality, include tests for expected behavior, validation failures, and relevant error cases.

### Frontend tests

Use the test command configured in the frontend's `package.json`. For example, if a test script is defined:

```bash
npm test
```

Verify available scripts before running commands:

```bash
npm run
```

Frontend tests should cover important component behavior, user interactions, loading states, and API error handling.

## Code Quality

Before submitting changes:

- Follow the existing code style and project conventions.
- Keep components and modules focused on a clear responsibility.
- Avoid duplicating business logic.
- Validate input on the backend.
- Handle API errors consistently.
- Add or update tests when behavior changes.
- Run the configured linters and tests.

If RuboCop is configured for the Rails application, run:

```bash
bin/rubocop
```

Use the frontend lint script if one is configured in `package.json`.

## Contributing

Contributions are welcome. Please follow the workflow below to keep changes consistent and reviewable.

### 1. Create an issue

Before implementing a substantial change, describe the problem or proposed feature. Discuss larger architectural changes before beginning implementation.

### 2. Create a branch

Create a descriptive branch from the main development branch:

```bash
git checkout main
git pull
git checkout -b feature/event-search
```

Choose a branch name appropriate to your change.

Suggested prefixes:

- `feature/` — new functionality
- `fix/` — bug fixes
- `docs/` — documentation changes
- `refactor/` — internal code improvements
- `test/` — test-related changes

### 3. Implement your changes

Keep changes focused and consistent with the existing architecture.

For API changes:
- Follow Rails conventions.
- Add appropriate validations and authorization checks.
- Use migrations for database schema changes.
- Add or update RSpec tests.

For frontend changes:
- Prefer reusable React components.
- Keep API communication separate from presentation logic.
- Handle loading, empty, success, and error states.
- Ensure layouts work on mobile and desktop.
- Add or update relevant tests.

### 4. Run checks locally

Run the relevant test suites and configured linters before submitting your changes.

Review your changes with:

```bash
git diff
git status
```

Make sure no credentials, generated files, or unrelated changes are included.

### 5. Commit your changes

Use clear, descriptive commit messages.

Examples:

```text
feat: add event search
fix: handle unavailable tickets
docs: update local setup instructions
test: add event model specs
refactor: extract event card component
```

### 6. Open a pull request

Push your branch:

```bash
git push -u origin feature/event-search
```

Open a pull request against the appropriate target branch.

Include:
- A summary of the changes.
- The reason for the change.
- Relevant issue references.
- Testing performed.
- Screenshots for significant UI changes, when applicable.
- Any migration or environment configuration notes.

Address review feedback before requesting final approval.

## Development Guidelines

### API and Data Integrity

The backend is the source of truth for ticket prices, availability, order status, and authorization.

The frontend must not be trusted to enforce purchase limits or calculate authoritative order totals. Validate these values on the server before confirming an order.

### Security

- Never store plaintext passwords.
- Do not expose private credentials in client-side code.
- Enforce authorization on protected API endpoints.
- Validate and sanitize untrusted input.
- Use a secure payment integration for financial transactions.
- Avoid logging sensitive user or payment information.

### Documentation

Update the relevant documentation when changing:

- Setup or environment requirements.
- API endpoints or request/response formats.
- Database schema.
- User-facing functionality.
- Testing or contribution workflows.

## License

The project license has not yet been specified. Add a `LICENSE` file and update this section once the licensing terms have been decided.
