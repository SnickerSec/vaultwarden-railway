# Documentation Index

This directory contains all documentation for the Vaultwarden Railway deployment.

## Getting Started

| Document | Description |
|----------|-------------|
| [QUICK_START.md](QUICK_START.md) | Get started in under 10 minutes |
| [DEPLOY.md](DEPLOY.md) | Detailed Vaultwarden deployment guide |

## Operations

| Document | Description |
|----------|-------------|
| [BACKUP.md](BACKUP.md) | Backup configuration and procedures |
| [RESTORE.md](RESTORE.md) | Database restore procedures |
| [UPDATES.md](UPDATES.md) | Version management and auto-updates |

## Security

| Document | Description |
|----------|-------------|
| [SECURITY.md](SECURITY.md) | Security best practices |
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
- Automated encrypted backups run daily at 3 AM UTC via GitHub Actions
- See [BACKUP.md](BACKUP.md) for configuration
- See [RESTORE.md](RESTORE.md) for restore procedures

### Security Hardening
1. Optional Google OAuth: [GOOGLE_AUTH_SETUP.md](GOOGLE_AUTH_SETUP.md)
2. Optional Cloudflare: [CLOUDFLARE_SETUP.md](CLOUDFLARE_SETUP.md)
