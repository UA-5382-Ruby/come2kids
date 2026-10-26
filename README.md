# Come2Kids

Come2Kids is a Ruby on Rails API project.

## Project Structure


come2kids/
├── api/      # Rails API
├── web/      # Future frontend
├── docs/     # Documentation
└── README.md


## Requirements

- Ruby 3.3.5
- PostgreSQL
- Node.js
- npm

## Ruby Setup

Install and manage Ruby using ASDF.


asdf plugin add ruby https://github.com/asdf-vm/asdf-ruby.git
asdf install ruby 3.3.5
asdf set ruby 3.3.5

Check the Ruby version:

ruby -v


## PostgreSQL Setup

Install PostgreSQL:

brew install postgresql

Start PostgreSQL:

brew services start postgresql


## Backend Setup

Go to the Rails API directory:
cd api

Install dependencies:
bundle install

Set up the database:
bin/rails db:setup

Start the Rails server:
bin/rails server

The API will be available at:
http://127.0.0.1:3000


## Testing

Run RSpec tests:
bundle exec rspec


## Code Style

Run RuboCop:
bundle exec rubocop

RuboCop is also executed automatically by GitHub Actions on pull requests.

## Branch Naming

Use a separate branch for each issue:
issue-<number>/short-description


Example:
issue-1/rails-skeleton
Do not make feature changes directly in the main branch.