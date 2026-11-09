# Environment Variables Configuration

This document outlines how environment variables are managed in the **Come2Kids** project to ensure secure and consistent configuration across different environments.

---

## Development Environment

For local development, database credentials come from environment variables (see `api/config/database.yml`) with local fallbacks. Typical values:

```bash
DB_HOST=127.0.0.1
DB_PORT=5432
DB_USERNAME=postgres
DB_PASSWORD=YOUR_PASSWORD_HERE
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

For local development, copy the template and adjust values:

```bash
cd api
cp .env.example .env
```

Key variables (see `api/.env.example` for the full list):

| Variable | Purpose | Example |
|----------|---------|---------|
| `DB_HOST` / `DB_USERNAME` / `DB_PASSWORD` | PostgreSQL connection | `127.0.0.1` / `postgres` |
| `REDIS_URL` | Sidekiq / Redis connection | `redis://localhost:6379/0` |
| `MONGODB_URI` | Activity / failure logs (Mongoid) | `mongodb://localhost:27017/come2kids_development` |
| `MAIL_HOST` / `MAIL_PORT` | Dev SMTP → Mailpit | `localhost` / `1025` |
| `MAIL_FROM` | Default From: address | `noreply@come2kids.local` |
| `SMTP_*` | Production SMTP settings | see `.env.example` |
| `SIDEKIQ_USERNAME` / `SIDEKIQ_PASSWORD` | HTTP Basic for `/sidekiq` | optional locally |
| `FRONTEND_ORIGINS` | CORS allowlist | `http://localhost:3000` |
| `SECRET_KEY_BASE` | Required in production / Compose | long random hex |

```bash
DATABASE_URL=postgresql://postgres:YOUR_PASSWORD_HERE@localhost:5432/come2kids_dev
RAILS_ENV=development
REDIS_URL=redis://localhost:6379/0
MONGODB_URI=mongodb://localhost:27017/come2kids_development
FRONTEND_ORIGINS=http://localhost:3000
```

> **Important:** Ensure that `.env` is listed in `.gitignore` to prevent accidental commits of sensitive data.

---

## Authentication

| Variable | Default | Description |
|---|---|---|
| `JWT_SECRET` | `secret_key_base` | Secret used to sign access tokens (HS256). Set a long random value in production. |
| `JWT_ISSUER` | `come2kids` | Value of the `iss` claim written to and required on access tokens. |
| `JWT_ACCESS_TTL` | `900` | Access token lifetime in seconds (15 minutes). |

---

## Security Best Practices

* Never commit sensitive information (passwords, API keys, secret tokens) to the Git repository.
* Use `.env` files for local environment variables and ensure `.env` is listed in `.gitignore`.
* For production secrets, rely on secure secret management systems or Rails encrypted credentials (`config/credentials.yml.enc`).
* Rotate passwords and keys regularly, especially if they are accidentally exposed.

## CORS

`FRONTEND_ORIGINS` is a comma-separated allowlist of browser origins. Include the scheme and port when needed, for example:

```bash
FRONTEND_ORIGINS=https://app.example.com,https://admin.example.com
```

In development, the default is `http://localhost:3000` when the variable is omitted. Production requires `FRONTEND_ORIGINS`; wildcard origins are not supported.

---

## Rails Encrypted Credentials

Rails provides a built-in mechanism for managing secrets:

```bash
# Edit credentials (opens in your default editor)
rails credentials:edit

# Set the master key for production
export RAILS_MASTER_KEY=your_master_key_here
```
