# Documentation Index

This directory contains all documentation for the Vaultwarden Railway deployment.

## Getting Started

| Document | Description |
|----------|-------------|
| [QUICK_START.md](QUICK_START.md) | Get started in under 10 minutes |
| [DEPLOY.md](DEPLOY.md) | Detailed Vaultwarden deployment guide |
| [MONITOR-DEPLOYMENT.md](MONITOR-DEPLOYMENT.md) | Deploy the backup monitoring dashboard |

## Operations

| Document | Description |
|----------|-------------|
| [BACKUP.md](BACKUP.md) | Backup configuration and procedures |
| [RESTORE.md](RESTORE.md) | Database restore procedures |
| [MONITORING.md](MONITORING.md) | Web-based monitoring dashboard |
| [UPDATES.md](UPDATES.md) | Version management and auto-updates |

## Security

| Document | Description |
|----------|-------------|
| [SECURITY.md](SECURITY.md) | Security best practices |
| [RATE_LIMITING.md](RATE_LIMITING.md) | Rate limiting configuration |
| [GOOGLE_AUTH_SETUP.md](GOOGLE_AUTH_SETUP.md) | Google OAuth pre-authentication |
| [CLOUDFLARE_SETUP.md](CLOUDFLARE_SETUP.md) | Cloudflare access control |

## Configuration

| Document | Description |
|----------|-------------|
| [EMAIL_SETUP.md](EMAIL_SETUP.md) | SMTP email notifications |
| [STRUCTURE.md](STRUCTURE.md) | Codebase organization and architecture |

## Quick Reference

### New Users
Start with [QUICK_START.md](QUICK_START.md) for a streamlined 10-minute setup.

### Backup & Restore
- Automated backups run daily at 3 AM UTC via GitHub Actions
- See [BACKUP.md](BACKUP.md) for configuration
- See [RESTORE.md](RESTORE.md) for restore procedures

### Monitoring Dashboard
- Deploy with [MONITOR-DEPLOYMENT.md](MONITOR-DEPLOYMENT.md)
- Access via `https://your-monitor-url.railway.app`
- See [MONITORING.md](MONITORING.md) for usage

### Security Hardening
1. Configure rate limiting: [RATE_LIMITING.md](RATE_LIMITING.md)
2. Optional Google OAuth: [GOOGLE_AUTH_SETUP.md](GOOGLE_AUTH_SETUP.md)
3. Optional Cloudflare: [CLOUDFLARE_SETUP.md](CLOUDFLARE_SETUP.md)
