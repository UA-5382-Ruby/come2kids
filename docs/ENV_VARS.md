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
CORS_ALLOWED_ORIGINS=http://localhost:3000
```

> **Important:** Ensure that `.env` is listed in `.gitignore` to prevent accidental commits of sensitive data.

### CORS

`CORS_ALLOWED_ORIGINS` contains the frontend origins allowed to make
cross-origin requests to the API. Separate multiple origins with commas:

```bash
CORS_ALLOWED_ORIGINS=http://localhost:3000,https://app.example.com
```

Configure this variable in each deployment environment. Do not use `*` when
the API accepts credentials or is accessed by a known frontend.

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
