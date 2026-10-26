# Come2Kids API

The backend for **Come2Kids**, an event discovery and ticketing platform, built with Ruby on Rails and PostgreSQL.

## Overview

This application provides the server-side foundation for the platform. It is responsible for handling API requests, applying application logic, and persisting data in PostgreSQL.

## Tech Stack

- Ruby
- Ruby on Rails
- PostgreSQL
- Bundler
- RSpec for tests
- RuboCop for linting

## Getting Started

### Prerequisites

- Ruby version specified by the project, if available in `.ruby-version`
- Bundler
- PostgreSQL

### Setup

Run these commands from the API directory:

```bash
bundle install
```

Configure the development database in `config/database.yml` or through the environment variables supported by the application. Ensure PostgreSQL is running and that the configured database and credentials exist.

Then initialize the database:

```bash
bin/rails db:setup
```

If the database already exists and only needs pending migrations, run:

```bash
bin/rails db:migrate
```

### Run the API

Start the Rails server:

```bash
bin/rails server
```

The server's URL and port depend on the Rails configuration; by default, Rails runs at `http://localhost:3000`.

## Development Commands

Run the test suite:

```bash
bundle exec rspec
```

Run RuboCop to check Ruby code style:

```bash
bundle exec rubocop
```

## Configuration

Keep local credentials and secrets out of version control. Use the application's existing environment-variable configuration or Rails credentials for sensitive values. Do not commit production credentials or real secrets.

## API Documentation

Document implemented endpoints here as the API evolves. For each endpoint, include the HTTP method, path, purpose, required parameters, request body, response format, and possible error responses. Do not assume an endpoint is available until it has been implemented.

## Notes

Commands and configuration in this README assume a standard Rails API setup. If the repository defines different scripts, Ruby versions, database names, or configuration conventions, follow the actual project configuration.
