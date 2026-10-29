# Come2Kids API

## OpenAPI documentation

Swagger UI is available at `/api-docs` when the API is running. The generated
OpenAPI document is served at `/api-docs/v1/swagger.yaml`.

Regenerate the documentation after changing an Rswag request spec:

```bash
bundle exec rake rswag:specs:swaggerize
```

The generated document is written to `swagger/v1/swagger.yaml`.

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...
