# Environment Configuration

## Overview

Environment variables allow the application to receive configuration values without hardcoding them into the source code.

Rails also uses `config/database.yml` and Rails credentials for configuration and secrets. Use the mechanism already adopted by the project.

## Configuration principles

- Keep passwords, API keys, and other secrets out of source control.
- Do not commit `.env` files containing real credentials.
- Use `.env.example` to document required variables with placeholder values, if the project uses dotenv.
- Configure production secrets through the deployment environment or an approved secrets manager.
- Never use production credentials in development or test environments.

## Database configuration

Database connection settings are commonly defined in `config/database.yml`. Depending on the project configuration, the application may use variables such as:

```env
DATABASE_URL=postgresql://localhost/come2kids
```

This is an example, not a confirmed requirement. Use the connection format and credentials expected by the actual application.

## Secrets

Rails credentials can store sensitive application settings. Use:

```bash
bin/rails credentials:edit
```

Do not share the resulting secrets or commit encryption keys such as `config/master.key` unless the project's deployment process explicitly requires secure handling of that key.

## Adding new variables

When introducing a variable:

1. Define where its value comes from.
2. Document its purpose and whether it is required.
3. Provide a safe example value where appropriate.
4. Validate that the application handles missing or invalid values.
5. Configure it in every environment where it is needed.
