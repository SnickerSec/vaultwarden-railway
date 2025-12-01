# Vaultwarden Railway - Codebase Structure

This document describes the organization of the Vaultwarden Railway codebase.

## Directory Structure

```
vaultwarden-railway/
├── archive/                    # Archived/deprecated configuration files
│   ├── README.md              # Archive documentation
│   └── nixpacks.toml          # Old build configuration
│
├── config/                     # Vaultwarden configuration templates
│   ├── docker/                # Docker-specific configs
│   ├── examples/              # Example configurations
│   ├── variants/              # Configuration variants (OAuth2, etc.)
│   └── README.md              # Configuration documentation
│
├── docs/                       # Project documentation
│   ├── BACKUP.md              # Backup procedures
│   ├── CLOUDFLARE_SETUP.md    # Cloudflare configuration
│   ├── DEPLOY.md              # Deployment instructions
│   ├── DEPLOYMENT_GUIDE.md    # Comprehensive deployment guide
│   ├── DEPLOYMENT_NOTES.md    # Deployment notes and tips
│   ├── DEPLOY_NOW.md          # Quick deployment guide
│   ├── EMAIL_SETUP.md         # Email service configuration
│   ├── GOOGLE_AUTH_SETUP.md   # Google OAuth setup
│   ├── MONITORING.md          # Monitoring and dashboard setup
│   ├── PROJECT_SUMMARY.md     # Project overview
│   ├── QUICK_START.md         # Quick start guide
│   ├── RATE_LIMITING.md       # Rate limiting configuration
│   ├── README.md              # Documentation index
│   ├── RESTORE.md             # Restore procedures
│   ├── SECURITY.md            # Security considerations
│   ├── SETUP_COMPLETE.md      # Post-setup checklist
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
│   ├── app.py                 # Flask application entry point
│   ├── config.py              # Application configuration
│   ├── Dockerfile             # Container build definition
│   ├── README.md              # Monitor documentation
│   ├── requirements.txt       # Python dependencies
│   ├── routes.py              # HTTP route handlers
│   ├── services.py            # Business logic layer
│   ├── setup.sh               # Setup script
│   └── utils.py               # Utility functions
│
├── scripts/                    # Operational scripts
│   ├── http-cleanup/          # HTTP URI cleanup utilities (one-time migration)
│   │   ├── cleanup-all.sh              # Clean all items
│   │   ├── cleanup-http-uris-apikey.sh # API key-based cleanup
│   │   ├── cleanup-http-uris-interactive.sh # Interactive cleanup
│   │   ├── cleanup-http-uris-v2.py     # Python v2 cleanup
│   │   ├── cleanup-http-uris.py        # Original Python cleanup
│   │   ├── cleanup-loop.sh             # Loop-based cleanup
│   │   ├── cleanup-simple.sh           # Simple cleanup
│   │   ├── count-http.sh               # Count HTTP URIs
│   │   ├── debug-item.sh               # Debug specific items
│   │   ├── fix-http-working.sh         # Working fix script
│   │   ├── fix-http.sh                 # Fix HTTP URIs
│   │   ├── run-until-done.sh           # Run until complete
│   │   ├── test-single.sh              # Test single item
│   │   ├── README-cleanup.md           # Cleanup documentation
│   │   └── USAGE.md                    # Usage instructions
│   │
│   ├── lib/                   # Shared script libraries
│   │   ├── backup.sh         # Backup functions
│   │   └── common.sh         # Common utilities
│   │
│   ├── backup-vault.sh        # Create database backup
│   ├── check-version.sh       # Check Vaultwarden version
│   ├── deploy-to-railway.sh   # Deploy to Railway
│   ├── generate-admin-token.sh # Generate admin token
│   ├── get-railway-ids.sh     # Get Railway service IDs
│   ├── restore-vault.sh       # Restore from backup
│   ├── setup-rate-limiting.sh # Setup rate limiting
│   └── verify-backup.sh       # Verify backup integrity
│
├── .gitignore                 # Git ignore patterns
├── MONITOR-DEPLOYMENT.md      # Monitor service deployment guide
├── README.md                  # Project README
├── railway.monitor.toml       # Railway config for monitor service
└── STRUCTURE.md              # This file

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

### HTTP Cleanup Utilities (`/scripts/http-cleanup`)
**Note:** These are one-time migration scripts used to convert HTTP URIs to HTTPS
in the Vaultwarden database. They are retained for reference but are not part
of normal operations.

### Documentation (`/docs`)
Comprehensive guides covering:
- Setup and deployment
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
- Python code follows Flask best practices
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
- Path traversal prevention (`is_safe_path()`)
- Filename sanitization
- Command injection prevention
- Password authentication
- Input validation

## Railway Deployment

The project is configured for Railway deployment with two services:

1. **Main Vaultwarden Service**
   - Runs official Vaultwarden container
   - PostgreSQL database
   - Persistent volume for data

2. **Monitor Service** (`/monitor`)
   - Custom Python/Flask dashboard
   - Access to Vaultwarden database
   - Persistent volume for backups
   - Configuration via `railway.monitor.toml`

See `MONITOR-DEPLOYMENT.md` and `docs/DEPLOYMENT_GUIDE.md` for details.

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
