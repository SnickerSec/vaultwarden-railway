# Vaultwarden Railway - Codebase Structure

This document describes the organization of the Vaultwarden Railway codebase.

## Directory Structure

```
vaultwarden-railway/
├── config/                     # Vaultwarden configuration templates
│   ├── docker/                # Docker-specific configs
│   ├── examples/              # Example configurations
│   ├── variants/              # Configuration variants (OAuth2, etc.)
│   └── README.md              # Configuration documentation
│
├── docs/                       # Project documentation
│   ├── BACKUP.md              # Backup procedures
│   ├── CLOUDFLARE_SETUP.md    # Cloudflare configuration
│   ├── DEPLOY.md              # Vaultwarden deployment guide
│   ├── EMAIL_SETUP.md         # Email service configuration
│   ├── GOOGLE_AUTH_SETUP.md   # Google OAuth setup
│   ├── MONITOR-DEPLOYMENT.md  # Monitor dashboard deployment
│   ├── MONITORING.md          # Monitoring and dashboard usage
│   ├── QUICK_START.md         # Quick start guide
│   ├── RATE_LIMITING.md       # Rate limiting configuration
│   ├── README.md              # Documentation index
│   ├── RESTORE.md             # Restore procedures
│   ├── SECURITY.md            # Security considerations
│   ├── STRUCTURE.md           # This file
│   └── UPDATES.md             # Update procedures
│
├── monitor/                    # Backup Monitor Dashboard (Python/Flask)
│   ├── scripts/               # Monitor-specific backup scripts
│   │   ├── lib/              # Shared script libraries
│   │   │   ├── backup.sh     # Backup functions
│   │   │   └── common.sh     # Common utilities
│   │   ├── backup-vault.sh   # Database backup script
│   │   ├── restore-vault.sh  # Database restore script
│   │   └── verify-backup.sh  # Backup verification script
│   ├── templates/             # HTML templates
│   │   └── index.html        # Main dashboard template
│   ├── tests/                 # Test suite
│   │   ├── conftest.py       # Pytest configuration
│   │   ├── test_routes.py    # Route tests
│   │   └── test_utils.py     # Utility function tests
│   ├── app.py                 # Flask application entry point
│   ├── config.py              # Application configuration
│   ├── extensions.py          # Flask extensions (CSRF, rate limiter)
│   ├── Dockerfile             # Container build definition
│   ├── README.md              # Monitor documentation
│   ├── requirements.txt       # Python dependencies
│   ├── routes.py              # HTTP route handlers
│   ├── services.py            # Business logic layer
│   ├── setup.sh               # Setup script
│   └── utils.py               # Utility functions
│
├── scripts/                    # Operational scripts
│   ├── lib/                   # Shared script libraries
│   │   ├── backup.sh         # Backup functions
│   │   └── common.sh         # Common utilities
│   ├── backup-vault.sh        # Create database backup
│   ├── check-version.sh       # Check Vaultwarden version
│   ├── deploy-to-railway.sh   # Deploy to Railway
│   ├── generate-admin-token.sh # Generate admin token
│   ├── get-railway-ids.sh     # Get Railway service IDs
│   ├── restore-vault.sh       # Restore from backup
│   ├── setup-rate-limiting.sh # Setup rate limiting
│   └── verify-backup.sh       # Verify backup integrity
│
├── .github/workflows/          # GitHub Actions
│   ├── backup-database.yml    # Daily database backup (3 AM UTC)
│   ├── check-version.yml      # Weekly version report
│   ├── restore-database.yml   # Manual database restore
│   └── update-vaultwarden.yml # Daily update checker (2 AM UTC)
│
├── .gitignore                 # Git ignore patterns
├── Dockerfile                 # Main Vaultwarden container
├── README.md                  # Project README
└── railway.monitor.toml       # Railway config for monitor service
```

## Key Components

### Monitor Dashboard (`/monitor`)
A Flask-based web application providing:
- Database backup management
- Backup verification
- Restore capabilities
- Vaultwarden status monitoring
- Version comparison with latest releases

### Core Scripts (`/scripts`)
Operational scripts for:
- Database backups and restores
- Version checking
- Railway deployment
- Admin token generation
- Rate limiting setup

### Documentation (`/docs`)
Comprehensive guides covering:
- Setup and deployment
- Monitor dashboard deployment
- Configuration options
- Security best practices
- Backup and restore procedures
- Third-party integrations

## Development Guidelines

### Adding New Scripts
- Place operational scripts in `/scripts`
- Use `/scripts/lib` for shared functions
- Add one-time maintenance scripts to `/scripts/maintenance` (gitignored)
- Document all scripts with usage comments

### Monitor Development
- Flask extensions initialized in `extensions.py` to avoid circular imports
- Security validations in `utils.py`
- Business logic in `services.py`
- HTTP handling in `routes.py`
- All user input is sanitized and validated

### Documentation
- Keep `/docs` up to date with changes
- Use Markdown format
- Include examples and screenshots where helpful
- Cross-reference related documents

## Security Notes

### Sensitive Data Locations (Gitignored)
- `/data` - Vaultwarden data directory
- `/backups` - Database backups
- `*.sql`, `*.sql.gz` - SQL dumps
- `.env` files - Environment variables
- Token and secret files

### Security Validations
The monitor dashboard implements:
- Path traversal prevention (`get_safe_path()`)
- Filename sanitization
- Command injection prevention
- Password authentication with rate limiting
- CSP nonces (no unsafe-inline)
- Session cookie security (Secure, HttpOnly, SameSite)
- Input validation

## Railway Deployment

The project is configured for Railway deployment with two services:

1. **Main Vaultwarden Service**
   - Runs official Vaultwarden container (pinned version)
   - PostgreSQL database
   - Persistent volume for data

2. **Monitor Service** (`/monitor`)
   - Custom Python/Flask dashboard
   - Access to Vaultwarden database
   - Persistent volume for backups
   - Configuration via `railway.monitor.toml`

See [MONITOR-DEPLOYMENT.md](MONITOR-DEPLOYMENT.md) and [DEPLOY.md](DEPLOY.md) for details.

## Version Control

### Tracked Files
- Source code (`.py`, `.sh`)
- Documentation (`.md`)
- Configuration templates
- Requirements and dependencies

### Ignored Files
- Sensitive data (backups, secrets, tokens)
- Generated files (logs, cache)
- Local development files
- Temporary scripts in `/scripts/maintenance`, `/scripts/local`, `/scripts/temp`

## Contributing

When making changes:
1. Update relevant documentation
2. Follow existing code style
3. Add comments for complex logic
4. Test thoroughly before committing
5. Update this STRUCTURE.md if adding new directories or major components
