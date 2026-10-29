# Environment Variables Configuration

This document outlines how environment variables are managed in the **Come2Kids** project to ensure secure and consistent configuration across different environments.

---

## Development Environment

For local development, database credentials and other settings are stored in the `api/config/database.yml` file. A typical development configuration looks like this:

```yaml
development:
  adapter: postgresql
  database: come2kids_dev
  username: postgres
  password: YOUR_PASSWORD_HERE
  host: localhost
  port: 5432
```

> **Note:** Replace `YOUR_PASSWORD_HERE` with the password you set during PostgreSQL installation.

---

## Production Environment

In production, sensitive configuration must never be hardcoded. Use environment variables or Rails encrypted credentials.

```bash
DATABASE_URL=postgresql://username:password@host:port/come2kids_production
RAILS_MASTER_KEY=your_master_key_here
```

---

## Managing Environment Variables Locally

For local development, you can use a `.env` file to store environment variables:

```bash
DATABASE_URL=postgresql://postgres:YOUR_PASSWORD_HERE@localhost:5432/come2kids_dev
RAILS_ENV=development
```

> **Important:** Ensure that `.env` is listed in `.gitignore` to prevent accidental commits of sensitive data.

---

## Authentication

| Variable | Default | Description |
|---|---|---|
| `JWT_SECRET` | `secret_key_base` | Secret used to sign access tokens (HS256). Set a long random value in production. |
| `JWT_ACCESS_TTL` | `900` | Access token lifetime in seconds (15 minutes). |
| `REFRESH_TOKEN_TTL_DAYS` | `30` | Refresh token lifetime in days. |
| `FRONTEND_ORIGIN` | `http://localhost:5173` in development/test; none otherwise | Comma-separated list of origins allowed by CORS (credentials enabled, so `*` is not allowed). Blank entries are ignored. Production must set this variable; when unset, no origins are allowed outside local environments. |

---

## Security Best Practices

* Never commit sensitive information (passwords, API keys, secret tokens) to the Git repository.
* Use `.env` files for local environment variables and ensure `.env` is listed in `.gitignore`.
* For production secrets, rely on secure secret management systems or Rails encrypted credentials (`config/credentials.yml.enc`).
* Rotate passwords and keys regularly, especially if they are accidentally exposed.

---

## Rails Encrypted Credentials

Rails provides a built-in mechanism for managing secrets:

```bash
# Edit credentials (opens in your default editor)
rails credentials:edit

# Set the master key for production
export RAILS_MASTER_KEY=your_master_key_here
```

