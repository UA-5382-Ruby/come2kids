# api

The come2kids Rails API (Rails 8.1, API-only, PostgreSQL).

Setup, RuboCop usage, branch naming and the pull request flow are in the
[root README](../README.md). Per-OS details and troubleshooting are in
[docs/setup.md](../docs/setup.md), environment variables in
[docs/environment.md](../docs/environment.md).

Run everything from this directory:

```bash
bundle install
bin/rails db:setup        # create and seed api_development and api_test
bin/dev                   # start the server on http://localhost:3000 (health check: /up)
bin/rails test            # run the test suite
bundle exec rubocop       # lint
bin/ci                    # full local check: lint, security scans, tests
```
