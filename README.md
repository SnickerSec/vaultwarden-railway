# Vaultwarden - Self-Hosted Password Manager for Railway

A lightweight, self-hosted password manager with built-in 2FA/OTP support, ready to deploy on Railway.

**Automatic Updates Enabled** - Always stays up-to-date with the latest Vaultwarden releases!

## Features

- Full password management with browser extensions and mobile apps
- Built-in TOTP/2FA authenticator (no need for separate authenticator apps)
- End-to-end encryption
- Bitwarden-compatible (use official Bitwarden apps)
- Secure password sharing
- Password generator
- Auto-fill capabilities
- Cross-platform support (Windows, macOS, Linux, iOS, Android)
- Web vault access
- **Automatic updates** via GitHub Actions (daily version checks)

## Quick Deploy to Railway

### Method 1: Deploy from GitHub (Recommended)

1. **Push this code to a GitHub repository**

2. **Create a new project on Railway**
   - Go to [railway.app](https://railway.app)
   - Click "New Project"
   - Select "Deploy from GitHub repo"
   - Choose your repository

3. **Configure environment variables**
   - Go to your project settings
   - Add these variables:
     ```
     DOMAIN=https://your-app.up.railway.app
     ADMIN_TOKEN=your-secure-random-token-here
     SIGNUPS_ALLOWED=true
     WEBSOCKET_ENABLED=true
     ```

   Generate a secure admin token:
   ```bash
   openssl rand -base64 48
   ```

4. **Add PostgreSQL Database (Optional but recommended)**
   - Click "New" → "Database" → "Add PostgreSQL"
   - Railway will automatically inject `DATABASE_URL`

5. **Deploy**
   - Railway will automatically detect the Dockerfile and deploy
   - Your app will be available at `https://your-app.up.railway.app`

### Method 2: Railway CLI

```bash
# Install Railway CLI
npm i -g @railway/cli

# Login
railway login

# Initialize project
railway init

# Add environment variables
railway variables set DOMAIN=https://your-app.up.railway.app
railway variables set ADMIN_TOKEN=$(openssl rand -base64 48)
railway variables set SIGNUPS_ALLOWED=true

# Deploy
railway up
```

## First-Time Setup

1. **Access your instance**
   - Navigate to your Railway app URL

2. **Create your account**
   - Click "Create Account"
   - Enter your email and master password
   - **IMPORTANT**: Save your master password securely - it cannot be recovered!

3. **Disable signups (recommended)**
   - After creating your account, go to Railway environment variables
   - Set `SIGNUPS_ALLOWED=false`
   - Redeploy the service

4. **Access admin panel**
   - Go to `https://your-app.up.railway.app/admin`
   - Enter your `ADMIN_TOKEN`
   - Review settings and user accounts

## Using 2FA/OTP

Vaultwarden includes a built-in TOTP authenticator:

1. In the web vault, go to Settings → Security → Two-step Login
2. Enable "Authenticator App (TOTP)"
3. Add 2FA codes for your other accounts in the password entries
4. Use the "TOTP" field when creating/editing password items

## Client Applications

Download official Bitwarden clients and point them to your instance:

- **Browser Extensions**: Chrome, Firefox, Safari, Edge, Opera
- **Desktop Apps**: Windows, macOS, Linux
- **Mobile Apps**: iOS, Android
- **CLI**: `bw config server https://your-app.up.railway.app`

Download from: https://bitwarden.com/download/

## Environment Variables Reference

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DOMAIN` | Yes | - | Your Railway app URL |
| `ADMIN_TOKEN` | Yes | - | Admin panel access token |
| `SIGNUPS_ALLOWED` | No | `true` | Allow new user registrations |
| `INVITATIONS_ALLOWED` | No | `true` | Allow user invitations |
| `WEBSOCKET_ENABLED` | No | `true` | Enable real-time sync |
| `SHOW_PASSWORD_HINT` | No | `false` | Show password hints |
| `LOG_LEVEL` | No | `info` | Logging level |
| `DATABASE_URL` | No | SQLite | PostgreSQL connection string |

## Email Configuration (Optional)

For password reset and 2FA recovery emails:

```bash
railway variables set SMTP_HOST=smtp.gmail.com
railway variables set SMTP_FROM=your-email@gmail.com
railway variables set SMTP_PORT=587
railway variables set SMTP_SECURITY=starttls
railway variables set SMTP_USERNAME=your-email@gmail.com
railway variables set SMTP_PASSWORD=your-app-password
```

## Backup Your Data

### Automated Daily Backups

This deployment includes **automated daily database backups**:

- Runs daily at 3 AM UTC via GitHub Actions
- PostgreSQL database dumps stored as artifacts
- 90-day retention in GitHub Actions
- Automatic notifications on failure

**Setup:** Add your Railway token to GitHub Secrets as `RAILWAY_TOKEN`

See **[docs/BACKUP.md](docs/BACKUP.md)** for complete backup and restore procedures.

### Manual Backup Options

1. **Backup script** (Quick local backup):
   ```bash
   ./scripts/backup-vault.sh
   ```

2. **Export from web vault**
   - Go to Tools → Export Vault
   - Save the encrypted JSON file securely

3. **Railway's database backup features**
   - Access via Railway dashboard → PostgreSQL → Backups

## Optional: Google OAuth Protection

Add an extra layer of security by requiring Google authentication before accessing Vaultwarden:

**Two-Layer Security:**
1. Google OAuth (controls who can see the login page)
2. Vaultwarden master password (protects your vault)

See **[GOOGLE_AUTH_SETUP.md](docs/GOOGLE_AUTH_SETUP.md)** for detailed setup instructions.

**Note:** This may interfere with Bitwarden mobile apps. Best for web-only access or advanced users.

## Security Best Practices

1. **Use a strong master password** - This is your only key to decrypt data
2. **Enable 2FA** on your Vaultwarden account
3. **Disable signups** after creating your account
4. **Configure rate limiting** - Protect against brute-force attacks (see below)
5. **Use HTTPS** - Railway provides this automatically (port 443)
6. **Backup regularly** - Export your vault periodically
7. **Keep admin token secret** - Never commit it to version control
8. **Use PostgreSQL** for production - More reliable than SQLite
9. **Consider Google OAuth** - Optional extra authentication layer

## Rate Limiting

Protect your instance from brute-force attacks with built-in rate limiting:

**Quick Setup:**
```bash
./scripts/setup-rate-limiting.sh
```

This configures:
- Login attempt limits (default: 10 per minute)
- Admin panel limits (default: 3 per 5 minutes)
- Proper IP detection for Railway

**Manual Configuration:**
Set these variables in Railway dashboard:
- `LOGIN_RATELIMIT_MAX_BURST=10`
- `LOGIN_RATELIMIT_SECONDS=60`
- `ADMIN_RATELIMIT_MAX_BURST=3`
- `ADMIN_RATELIMIT_SECONDS=300`
- `IP_HEADER=X-Forwarded-For`

See **[docs/RATE_LIMITING.md](docs/RATE_LIMITING.md)** for detailed configuration options and security levels.

## Troubleshooting

### Cannot access admin panel
- Ensure `ADMIN_TOKEN` is set correctly
- Try regenerating the token: `openssl rand -base64 48`

### Cannot create account
- Check `SIGNUPS_ALLOWED=true`
- Verify `DOMAIN` is set correctly

### Apps won't connect
- Ensure `DOMAIN` matches your Railway URL exactly
- Include `https://` in the domain
- Check Railway logs for errors

### Data not syncing
- Enable `WEBSOCKET_ENABLED=true`
- Check browser console for WebSocket errors

## Local Development

```bash
# Copy environment file
cp config/.env.example .env

# Edit .env with your settings
nano .env

# Run with Docker Compose
docker-compose up -d

# View logs
docker-compose logs -f

# Access at http://localhost:80
```

## Automatic Updates

This deployment includes automatic update capabilities:

- **Daily version checks** via GitHub Actions
- **Auto-deploy** when new versions are released
- **Weekly status reports** for monitoring
- **Manual version checking** with included scripts

For detailed information on updates, see **[UPDATES.md](docs/UPDATES.md)**

### Quick Version Check

```bash
# Check current vs latest version
./scripts/check-version.sh
```

## Resources

- [Vaultwarden Wiki](https://github.com/dani-garcia/vaultwarden/wiki)
- [Bitwarden Help Center](https://bitwarden.com/help/)
- [Railway Documentation](https://docs.railway.app/)
- [Update Guide](docs/UPDATES.md) - Automatic update documentation
- [Backup Guide](docs/BACKUP.md) - Automated and manual backup procedures
- [Rate Limiting Guide](docs/RATE_LIMITING.md) - Protection against brute-force attacks
- [Deployment Guide](docs/DEPLOY.md) - Detailed Railway setup
- [Quick Start Guide](docs/QUICK_START.md) - Fast setup walkthrough
- [Security Guide](docs/SECURITY.md) - Security best practices and admin token setup
- [Cloudflare Setup](docs/CLOUDFLARE_SETUP.md) - Optional access control

## License

This deployment configuration is provided as-is. Vaultwarden is licensed under GPL-3.0.

## Support

For issues with:
- Vaultwarden: https://github.com/dani-garcia/vaultwarden/issues
- Railway: https://help.railway.app/
- Bitwarden clients: https://bitwarden.com/help/
