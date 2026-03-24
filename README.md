# Vaultwarden - Self-Hosted Password Manager for Railway

A lightweight, self-hosted password manager with built-in 2FA/OTP support, ready to deploy on Railway.

## Features

- Full password management with browser extensions and mobile apps
- Built-in TOTP/2FA authenticator
- End-to-end encryption
- Bitwarden-compatible (use official Bitwarden apps)
- Automatic daily backups with web-based monitoring dashboard
- Automatic updates via GitHub Actions

## Quick Start

### 1. Deploy to Railway

```bash
# Clone and push to your GitHub
git clone https://github.com/your-repo/vaultwarden-railway.git
# Connect to Railway via dashboard or CLI
```

### 2. Configure Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `DOMAIN` | Yes | Your Railway app URL (e.g., `https://your-app.up.railway.app`) |
| `ADMIN_TOKEN` | Yes | Admin panel access token |
| `SIGNUPS_ALLOWED` | No | Allow new registrations (default: `true`) |
| `DATABASE_URL` | No | PostgreSQL connection (auto-injected by Railway) |

Generate a secure admin token:
```bash
openssl rand -base64 48
```

### 3. Add PostgreSQL Database

In Railway dashboard: New → Database → Add PostgreSQL

### 4. First-Time Setup

1. Navigate to your Railway app URL
2. Create your account
3. Set `SIGNUPS_ALLOWED=false` after registration
4. Access admin panel at `/admin`

## Documentation

| Guide | Description |
|-------|-------------|
| [docs/QUICK_START.md](docs/QUICK_START.md) | 10-minute setup guide |
| [docs/DEPLOY.md](docs/DEPLOY.md) | Detailed deployment |
| [docs/MONITOR-DEPLOYMENT.md](docs/MONITOR-DEPLOYMENT.md) | Monitor dashboard deployment |
| [docs/BACKUP.md](docs/BACKUP.md) | Backup configuration |
| [docs/RESTORE.md](docs/RESTORE.md) | Restore procedures |
| [docs/MONITORING.md](docs/MONITORING.md) | Web dashboard |
| [docs/SECURITY.md](docs/SECURITY.md) | Security best practices |
| [docs/STRUCTURE.md](docs/STRUCTURE.md) | Codebase organization |
| [docs/README.md](docs/README.md) | Full documentation index |

## Scripts

```bash
# Backup database
./scripts/backup-vault.sh

# Restore from backup
./scripts/restore-vault.sh backups/backup.sql.gz

# Verify backup integrity
./scripts/verify-backup.sh --list

# Check for updates
./scripts/check-version.sh

# Configure rate limiting
./scripts/setup-rate-limiting.sh
```

## Project Structure

```
vaultwarden-railway/
├── .github/workflows/   # GitHub Actions (backups, updates)
├── config/              # Configuration files
│   ├── examples/        # Environment templates
│   ├── docker/          # Docker Compose for local dev
│   └── variants/        # OAuth2 and other variants
├── docs/                # Documentation
├── monitor/             # Web monitoring dashboard
│   ├── app.py           # Flask application
│   ├── config.py        # Configuration
│   ├── routes.py        # API routes
│   ├── services.py      # Business logic
│   └── utils.py         # Utilities
├── scripts/             # Utility scripts
│   ├── lib/             # Shared shell libraries
│   ├── backup-vault.sh
│   ├── restore-vault.sh
│   └── ...
├── Dockerfile           # Main container
└── railway.toml         # Railway configuration
```

## Security

1. Use a strong master password
2. Enable 2FA on your account
3. Disable signups after registration
4. Configure rate limiting: `./scripts/setup-rate-limiting.sh`
5. Optional: Add Google OAuth ([docs/GOOGLE_AUTH_SETUP.md](docs/GOOGLE_AUTH_SETUP.md))

## Client Applications

Download official Bitwarden clients and configure your server URL:

- **Browser**: Chrome, Firefox, Safari, Edge
- **Desktop**: Windows, macOS, Linux
- **Mobile**: iOS, Android
- **CLI**: `bw config server https://your-app.up.railway.app`

Download: https://bitwarden.com/download/

## Resources

- [Vaultwarden Wiki](https://github.com/dani-garcia/vaultwarden/wiki)
- [Bitwarden Help](https://bitwarden.com/help/)
- [Railway Docs](https://docs.railway.app/)

## License

This deployment configuration is provided as-is. Vaultwarden is licensed under GPL-3.0.
