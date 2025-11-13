# Vaultwarden Deployment Notes

## Deployment Information

**Instance URL:** https://vaultwarden-railway-production.up.railway.app
**Deployed:** November 13, 2025
**Platform:** Railway (US West - California)
**Database:** PostgreSQL
**Storage:** Railway Volume (`vaultwarden-railway-volume`, 5GB, mounted at `/data`)

## Configuration

### Environment Variables Set:
- `DOMAIN` - Railway production URL
- `ADMIN_TOKEN` - Secured admin access
- `SIGNUPS_ALLOWED=false` - Signups disabled for security
- `DATABASE_URL` - PostgreSQL connection (auto-injected)
- `ROCKET_PORT=80`
- `ROCKET_ADDRESS=0.0.0.0`
- `WEBSOCKET_ENABLED=true`

### Security Features Enabled:
- ✅ 2FA enabled on account
- ✅ Signups disabled
- ✅ PostgreSQL database for production reliability
- ✅ Persistent volume for data storage
- ✅ HTTPS enabled (Railway automatic)
- ✅ Admin token configured

## Important Notes

### Health Check Issue
The `/alive` healthcheck endpoint was causing deployment failures. **Healthcheck has been removed from `railway.toml`**. The container starts successfully without it and Railway routes traffic correctly.

### Volume Configuration
Volume management is done **entirely through Railway dashboard**, not via `railway.toml`. The volume `vaultwarden-railway-volume` must be created and attached through the UI.

### Database Migration
- Initially used SQLite (in volume)
- Migrated to PostgreSQL for better reliability
- Old SQLite file remains in volume but is unused
- All data now stored in Railway PostgreSQL service

## Maintenance

### Checking Logs
```bash
# Via Railway dashboard
# Service → Deployments → Select deployment → View logs

# Or via CLI (requires railway link first)
railway logs
```

### Updating Vaultwarden
Automatic updates on every rebuild (pulls `latest` tag):
```bash
git commit --allow-empty -m "chore: trigger Vaultwarden update"
git push
```

### Backing Up Data
1. **Vault Export** (from web vault):
   - Tools → Export Vault → Encrypted JSON
   - Store securely

2. **Database Backup** (PostgreSQL):
   - Railway automatically backs up PostgreSQL
   - Can also use Railway's database backup features

### Accessing Admin Panel
URL: https://vaultwarden-railway-production.up.railway.app/admin
- Use the password you set with the Argon2 hash generator
- Or use the plain text token if not yet upgraded

## Connected Devices
- Browser extensions (set server URL in settings)
- Mobile apps (iOS/Android)
- Desktop apps (Windows/Mac/Linux)
- All pointed to: https://vaultwarden-railway-production.up.railway.app

## Troubleshooting

### Service Won't Start
- Check Railway logs for errors
- Verify volume is attached
- Ensure DATABASE_URL is set correctly
- Check environment variables are set

### Can't Access Site
- Verify domain in Railway matches DOMAIN variable
- Check deployment status (should be "Active")
- Try accessing without healthcheck enabled

### Lost Master Password
**Cannot be recovered!** Master password is used to encrypt vault data.
- No admin can recover it
- No backdoor exists
- Must create new account if lost

## Repository Structure
```
vaultwarden-railway/
├── Dockerfile              # Main deployment
├── railway.toml            # Railway config (no healthcheck)
├── README.md               # Main documentation
├── config/                 # Configuration files
│   ├── .env.example
│   ├── docker-compose.yml
│   ├── Dockerfile.oauth2
│   └── railway-oauth2.toml
├── docs/                   # Documentation
│   ├── DEPLOY.md
│   ├── SECURITY.md
│   ├── QUICK_START.md
│   └── ...
└── scripts/                # Utility scripts
    ├── generate-admin-token.sh
    ├── backup-vault.sh
    └── check-version.sh
```

## Next Steps

Your Vaultwarden instance is fully operational!

**Regular Maintenance:**
- Export vault monthly (encrypted backup)
- Check for updates occasionally
- Monitor Railway usage/costs
- Review admin panel settings

**Optional Enhancements:**
- Configure SMTP for email (password hints, 2FA recovery)
- Add custom domain
- Set up Google OAuth (see docs/GOOGLE_AUTH_SETUP.md)
- Add Cloudflare access control (see docs/CLOUDFLARE_SETUP.md)

## Support Resources
- Vaultwarden: https://github.com/dani-garcia/vaultwarden/wiki
- Railway: https://docs.railway.app/
- Bitwarden Help: https://bitwarden.com/help/
