# Come2Kids API - Setup Guide

## Overview

Come2Kids API is a backend application built with Ruby on Rails and PostgreSQL. This guide explains how to prepare the development environment and run the application locally.

## Prerequisites

Make sure the following tools are installed:

- Ruby (the version specified in `.ruby-version`, if available)
- RubyGems
- Bundler
- PostgreSQL
- Git

## Installation

### 1. Clone the repository

```bash
git clone <repository-url>
cd api
```

Replace `<repository-url>` with the actual repository URL.

### 2. Install dependencies

```bash
bundle install
```

Bundler installs the gems declared in the `Gemfile`.

### 3. Configure the environment

Review the application's environment variables and database configuration before starting the server.

### 4. Prepare the database

```bash
bin/rails db:create
bin/rails db:migrate
```

These commands create the configured database and apply pending migrations.

### 5. Run the test suite

```bash
bundle exec rspec
```

If no examples have been defined yet, RSpec may report that no examples were found.

### 6. Start the development server

```bash
bin/rails server
```

The API will normally be available at:

`http://localhost:3000`

Check the application's routes and controller implementation to determine which endpoints are available.
