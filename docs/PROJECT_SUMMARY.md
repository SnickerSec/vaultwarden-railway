# Vaultwarden Railway Deployment - Project Summary

## What This Is

A complete, production-ready deployment of **Vaultwarden** - a self-hosted password manager with automatic updates, configured specifically for Railway deployment.

## Key Features

### Core Functionality
- 🔐 Full password management with end-to-end encryption
- 📱 Built-in 2FA/OTP authenticator (TOTP support)
- 🔄 Automatic version updates (daily checks)
- 🌐 Cross-platform support (Web, iOS, Android, Windows, macOS, Linux)
- 🔒 Zero-knowledge architecture
- 📤 Password import/export
- 👥 Secure password sharing

### Automatic Updates System
- **GitHub Actions workflow** checks Docker Hub daily for new versions
- **Auto-deployment** triggers when updates are available
- **Weekly reports** showing version status
- **Manual scripts** for on-demand version checking
- **Rollback capability** if issues occur

### Railway Integration
- **One-click deployment** from GitHub
- **Auto-scaling** and health monitoring
- **HTTPS enabled** by default
- **PostgreSQL integration** optional but recommended
- **Environment variable** management
- **Deployment history** and logs

## Project Structure

```
vaultwarden-railway/
├── Dockerfile                          # Docker container configuration
├── railway.toml                        # Railway deployment settings
├── docker-compose.yml                  # Local development setup
├── .env.example                        # Environment variables template
│
├── .github/workflows/
│   ├── update-vaultwarden.yml         # Daily update checker (2 AM UTC)
│   └── check-version.yml              # Weekly version reporter
│
├── scripts/
│   ├── check-version.sh               # Manual version checker
│   └── backup-vault.sh                # Backup helper script
│
├── README.md                           # Main documentation
├── QUICK_START.md                      # 10-minute setup guide
├── DEPLOY.md                           # Detailed Railway deployment
├── UPDATES.md                          # Update management guide
└── PROJECT_SUMMARY.md                  # This file
```

## How Automatic Updates Work

### 1. Daily Version Check (GitHub Actions)
```
2 AM UTC → Check Docker Hub → Compare versions → Trigger update if available
```

- Runs automatically via `.github/workflows/update-vaultwarden.yml`
- Compares current version with latest release
- Creates empty commit to trigger Railway deployment
- Posts GitHub issue notification

### 2. Railway Auto-Deploy
```
Git push → Railway webhook → Pull latest image → Build → Deploy → Health check
```

- Configured in `railway.toml`
- Zero-downtime deployment
- Automatic rollback on health check failure
- Deployment history preserved

### 3. Notification System
- GitHub issue created on successful update
- Email notifications (if GitHub notifications enabled)
- Weekly status reports via GitHub Actions

## Security Features

1. **End-to-end encryption** - Master password never leaves your device
2. **Zero-knowledge architecture** - Server cannot decrypt your data
3. **HTTPS enforced** - Railway provides automatic SSL
4. **2FA/TOTP support** - Both for vault access and stored passwords
5. **Admin panel protection** - Requires secure token
6. **Signup control** - Can disable after initial setup
7. **Audit logs** - Track access patterns

## Deployment Options

### Quick Deploy (10 minutes)
Follow **QUICK_START.md** for fastest setup

### Standard Deploy (30 minutes)
Follow **DEPLOY.md** for detailed walkthrough

### CLI Deploy
```bash
railway login
railway init
railway variables set DOMAIN=https://your-app.up.railway.app
railway variables set ADMIN_TOKEN=$(openssl rand -base64 48)
railway up
```

## Environment Variables

### Required
| Variable | Description | Example |
|----------|-------------|---------|
| `DOMAIN` | Your Railway URL | `https://app.up.railway.app` |
| `ADMIN_TOKEN` | Admin panel access | Generate with `openssl rand -base64 48` |

### Recommended
| Variable | Default | Description |
|----------|---------|-------------|
| `SIGNUPS_ALLOWED` | `true` | Allow new user registration |
| `WEBSOCKET_ENABLED` | `true` | Real-time sync support |
| `DATABASE_URL` | SQLite | PostgreSQL connection (auto-injected) |

### Optional (Email)
- `SMTP_HOST`, `SMTP_FROM`, `SMTP_USERNAME`, `SMTP_PASSWORD`
- `SMTP_PORT`, `SMTP_SECURITY`

## Client Applications

All official Bitwarden clients work with Vaultwarden:

- **Browser**: Chrome, Firefox, Safari, Edge, Opera, Brave
- **Desktop**: Windows, macOS, Linux
- **Mobile**: iOS, Android
- **CLI**: `bw` command-line tool
- **Web**: Direct browser access

Download from: https://bitwarden.com/download/

## Cost Breakdown

### Railway (estimated)
- **Hobby Plan**: $5/month credit (requires credit card)
- **Vaultwarden usage**: ~$2-4/month
- **PostgreSQL**: Included in usage
- **Free tier**: 500 hours/month without credit card

### Vaultwarden
- **License**: GPL-3.0 (Free and Open Source)
- **No subscription fees** (unlike hosted Bitwarden)
- **All premium features** included free

## Maintenance

### Automated
- ✅ Version updates (daily checks)
- ✅ Deployments (auto-triggered)
- ✅ Health monitoring (Railway)
- ✅ SSL certificate renewal (Railway)

### Manual (Recommended)
- Export vault backup (weekly)
- Review update notifications (as needed)
- Check Railway logs (monthly)
- Test restore process (quarterly)

## Backup Strategy

### Automated (Railway)
- Database backups (if using PostgreSQL)
- Deployment history
- Environment variable snapshots

### Manual (Required)
1. **Vault export**: Tools → Export Vault → Encrypted JSON
2. **Store securely**: Off-site encrypted storage
3. **Test restore**: Import backup to verify integrity

Use `./scripts/backup-vault.sh` for backup guidance.

## Update Management

### Check Version
```bash
./scripts/check-version.sh
```

### Manual Update
```bash
git commit --allow-empty -m "Update Vaultwarden"
git push
```

### Disable Auto-Updates
Rename `.github/workflows/update-vaultwarden.yml` to add `.disabled` extension

### Rollback
Railway Dashboard → Deployments → Select previous version → Redeploy

## Monitoring

### Railway Dashboard
- Service health status
- Resource usage (CPU, memory)
- Deployment history
- Real-time logs

### GitHub Actions
- Workflow run history
- Update notifications (Issues)
- Version reports (Artifacts)

### Manual Checks
```bash
# Health check
curl https://your-app.up.railway.app/alive

# Version check
./scripts/check-version.sh

# View logs
railway logs
```

## Troubleshooting Quick Reference

| Issue | Solution |
|-------|----------|
| Can't access instance | Check Railway URL, wait for deployment |
| Admin panel locked | Verify `ADMIN_TOKEN` variable |
| Signups not working | Set `SIGNUPS_ALLOWED=true` |
| Extension won't connect | Use exact Railway URL with `https://` |
| Data not syncing | Enable `WEBSOCKET_ENABLED=true` |
| Update not deploying | Check GitHub Actions logs |

See **DEPLOY.md** for detailed troubleshooting.

## Documentation Index

| File | Purpose | Audience |
|------|---------|----------|
| **QUICK_START.md** | 10-minute setup guide | New users |
| **README.md** | Feature overview & basic usage | All users |
| **DEPLOY.md** | Detailed Railway deployment | Deployers |
| **UPDATES.md** | Update management & automation | Maintainers |
| **PROJECT_SUMMARY.md** | Architecture & overview | Developers |

## Support Resources

### Official Documentation
- [Vaultwarden Wiki](https://github.com/dani-garcia/vaultwarden/wiki)
- [Railway Docs](https://docs.railway.app/)
- [Bitwarden Help](https://bitwarden.com/help/)

### Community
- [Vaultwarden GitHub](https://github.com/dani-garcia/vaultwarden)
- [Railway Discord](https://discord.gg/railway)
- [Bitwarden Community](https://community.bitwarden.com/)

### This Repository
- GitHub Issues (for this deployment)
- Update notifications (auto-created issues)
- Version reports (workflow artifacts)

## Contributing

Improvements welcome:
1. Fork the repository
2. Create feature branch
3. Test changes locally with `docker-compose up`
4. Submit pull request

## License

- **This deployment configuration**: MIT License (use freely)
- **Vaultwarden**: GPL-3.0 License
- **Bitwarden clients**: Various open source licenses

## Credits

- **Vaultwarden**: [dani-garcia/vaultwarden](https://github.com/dani-garcia/vaultwarden)
- **Bitwarden**: [bitwarden](https://github.com/bitwarden)
- **Railway**: [railway.app](https://railway.app)

---

**Last Updated**: 2025-11-12
**Vaultwarden Version**: Uses `latest` tag (auto-updated)
**Compatible Railway**: v2 (current)
