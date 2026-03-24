# Vaultwarden Backup Monitoring Dashboard

A web dashboard for monitoring and managing Vaultwarden database backups.

## Features

- Real-time system status (Vaultwarden online/version, backup count, storage)
- One-click backup creation, verification, and restore
- Backup deletion with confirmation
- Restore and verification log viewer
- Webhook notifications for backup/restore failures
- Session-based authentication with rate limiting
- Responsive dark-theme UI

## Quick Start

### 1. Setup

```bash
cd monitor
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### 2. Configure

```bash
# Generate a password hash
python3 -c "from werkzeug.security import generate_password_hash; print(generate_password_hash('your-password'))"

# Set required environment variables
export MONITOR_PASSWORD_HASH='<paste-hash-here>'
export MONITOR_SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_hex(32))")
```

### 3. Run

```bash
python3 app.py
```

Open **http://localhost:5000** and log in with your password.

## Configuration

All configuration is via environment variables:

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `MONITOR_PASSWORD_HASH` | Yes | — | Werkzeug password hash |
| `MONITOR_SECRET_KEY` | No | Random | Session secret key |
| `MONITOR_PORT` | No | `5000` | Server port |
| `MONITOR_DEBUG` | No | `false` | Debug mode |
| `VAULTWARDEN_URL` | No | — | Vaultwarden instance URL for status checks |
| `BACKUP_DIR` | No | `../backups` | Backup storage directory |
| `SCRIPTS_DIR` | No | `../scripts` | Shell scripts directory |
| `NOTIFICATION_WEBHOOK_URL` | No | — | Webhook URL for failure notifications |

## Docker

```bash
docker build -t vaultwarden-monitor .
docker run -d \
  --name vaultwarden-monitor \
  -p 5000:5000 \
  -v /path/to/backups:/backups \
  -v /path/to/scripts:/scripts \
  -e MONITOR_PASSWORD_HASH="<your-hash>" \
  -e MONITOR_SECRET_KEY="<your-secret>" \
  vaultwarden-monitor
```

## Railway Deployment

See [docs/MONITOR-DEPLOYMENT.md](../docs/MONITOR-DEPLOYMENT.md) for the full deployment guide.

## API

All API endpoints are under `/api/`. Protected endpoints require session authentication.

### Authentication

```bash
# Login (creates session)
curl -X POST http://localhost:5000/api/login \
  -H "Content-Type: application/json" \
  -d '{"password": "your-password"}'

# Logout
curl -X POST http://localhost:5000/api/logout
```

### Endpoints (require auth)

```bash
# System status
curl http://localhost:5000/api/status

# List backups
curl http://localhost:5000/api/backups

# Create backup
curl -X POST http://localhost:5000/api/backups/create

# Verify backup
curl -X POST http://localhost:5000/api/backups/verify \
  -H "Content-Type: application/json" \
  -d '{"backup_path": "backup_20250101.sql.gz"}'

# Restore from backup
curl -X POST http://localhost:5000/api/backups/restore \
  -H "Content-Type: application/json" \
  -d '{"backup_path": "backup_20250101.sql.gz", "force": true}'

# Delete backup
curl -X POST http://localhost:5000/api/backups/delete \
  -H "Content-Type: application/json" \
  -d '{"backup_path": "backup_20250101.sql.gz"}'
```

### Public Endpoints

```bash
# Health check
curl http://localhost:5000/health
```

## Running Tests

```bash
cd monitor
MONITOR_PASSWORD_HASH='pbkdf2:sha256:600000$test$test' python3 -m pytest tests/ -v
```

## Project Structure

```
monitor/
├── app.py              # Flask application factory
├── config.py           # Configuration from env vars
├── extensions.py       # Flask extensions (CSRF, rate limiter)
├── routes.py           # API route handlers
├── services.py         # Business logic layer
├── utils.py            # Utility functions
├── templates/
│   └── index.html      # Single-page dashboard
├── tests/
│   ├── conftest.py     # Pytest fixtures
│   ├── test_routes.py  # Route tests
│   └── test_utils.py   # Utility function tests
├── requirements.txt    # Python dependencies
├── Dockerfile          # Container config
└── .env.example        # Example configuration
```

## Security

- Session-based auth with secure cookies (HttpOnly, Secure, SameSite)
- Login rate limiting (5 attempts/minute)
- CSP with per-request nonces (no unsafe-inline)
- Path traversal prevention via `secure_filename()` + `get_safe_path()`
- Command injection prevention: `shell=False` + command whitelist
- Non-root Docker container user
- 30-minute session timeout

## License

Part of the Vaultwarden Railway deployment project.
