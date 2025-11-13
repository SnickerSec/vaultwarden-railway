# Quick Start Guide

Get your Vaultwarden password manager running on Railway in under 10 minutes!

## Prerequisites

- GitHub account
- Railway account (free tier available)
- Git installed locally

## Step 1: Clone and Push to GitHub (2 minutes)

```bash
# Navigate to the project
cd vaultwarden-railway

# Initialize git repository
git init

# Add all files
git add .

# Commit
git commit -m "Initial Vaultwarden deployment"

# Create a new repository on GitHub, then:
git remote add origin https://github.com/YOUR_USERNAME/vaultwarden-railway.git
git branch -M main
git push -u origin main
```

## Step 2: Deploy to Railway (3 minutes)

1. Go to [railway.app](https://railway.app) and sign in
2. Click **"New Project"**
3. Select **"Deploy from GitHub repo"**
4. Choose your **vaultwarden-railway** repository
5. Railway will automatically start building

## Step 3: Configure Environment (2 minutes)

1. Click on your deployed service
2. Go to **"Variables"** tab
3. Click **"New Variable"** and add:

```bash
DOMAIN=https://your-app.up.railway.app
ADMIN_TOKEN=<paste-generated-token>
SIGNUPS_ALLOWED=true
WEBSOCKET_ENABLED=true
```

**Generate Admin Token:**
```bash
openssl rand -base64 48
```

4. Copy your Railway URL from the **"Settings"** tab and update `DOMAIN` variable

## Step 4: Add Database (1 minute) [OPTIONAL]

For production use:

1. Click **"New"** → **"Database"** → **"PostgreSQL"**
2. Railway automatically connects it to your service
3. Done! `DATABASE_URL` is auto-injected

## Step 5: Create Your Account (1 minute)

1. Visit your Railway URL (e.g., `https://your-app.up.railway.app`)
2. Click **"Create Account"**
3. Enter your email and **strong master password**
4. **CRITICAL**: Save your master password securely - it cannot be recovered!

## Step 6: Secure Your Instance (1 minute)

1. Go back to Railway **Variables**
2. Change `SIGNUPS_ALLOWED=false`
3. Railway will auto-redeploy

## You're Done! 🎉

Your password manager is now live with:
- ✅ End-to-end encryption
- ✅ Built-in 2FA/OTP authenticator
- ✅ Automatic updates enabled
- ✅ HTTPS enabled
- ✅ Cross-platform support

## Next Steps

### Install Browser Extension

1. Install Bitwarden extension for your browser
2. Click the extension icon → Settings (gear icon)
3. Enter Server URL: `https://your-app.up.railway.app`
4. Log in with your credentials

### Install Mobile App

1. Download Bitwarden app (iOS/Android)
2. On login screen, tap settings icon
3. Enter Server URL: `https://your-app.up.railway.app`
4. Log in

### Enable 2FA on Your Account

1. In web vault: Settings → Security → Two-step Login
2. Choose "Authenticator App (TOTP)"
3. Scan QR code with any authenticator app
4. Enter code to verify

### Add Your First Password

1. Click **"+ New Item"** in web vault
2. Enter website, username, password
3. Optional: Add TOTP secret in "Authenticator Key (TOTP)" field
4. Save

### Explore Features

- **Password Generator**: Auto-generate strong passwords
- **Collections**: Organize passwords into folders
- **Secure Notes**: Store sensitive text
- **Password Sharing**: Share with trusted users
- **Auto-fill**: Automatic form filling in browsers

## Automatic Updates

Your instance will automatically update:
- **Daily checks** for new Vaultwarden versions
- **Auto-deployment** when updates are available
- **GitHub notifications** when updates occur

Check update status:
```bash
./scripts/check-version.sh
```

## Backup Reminder

Before relying on your password manager:

1. **Export your vault**: Tools → Export Vault → Encrypted JSON
2. **Save securely**: Store backup in safe location
3. **Test restore**: Verify you can import the backup

## Support & Documentation

- **Full Setup Guide**: [DEPLOY.md](DEPLOY.md)
- **Update Management**: [UPDATES.md](UPDATES.md)
- **Feature Documentation**: [README.md](README.md)

## Troubleshooting

### Can't access after deployment
- Wait 2-3 minutes for initial build
- Check Railway logs for errors
- Verify DOMAIN matches your Railway URL exactly

### Can't create account
- Ensure `SIGNUPS_ALLOWED=true`
- Check Railway service is running
- Verify no error in Railway logs

### Browser extension won't connect
- Include `https://` in server URL
- Match Railway URL exactly
- Clear browser cache

### Admin panel not loading
- Verify `ADMIN_TOKEN` is set
- URL should be: `https://your-app.up.railway.app/admin`
- Token must be exact match

## Quick Reference

| Task | Command/URL |
|------|-------------|
| Web Vault | `https://your-app.up.railway.app` |
| Admin Panel | `https://your-app.up.railway.app/admin` |
| Check Version | `./scripts/check-version.sh` |
| View Logs | `railway logs` or Railway dashboard |
| Backup | Tools → Export Vault in web interface |
| Update | Automatic (daily checks) |

## Security Checklist

After setup, verify:
- ✅ Strong master password created
- ✅ Master password stored securely
- ✅ `SIGNUPS_ALLOWED=false` after account creation
- ✅ 2FA enabled on your account
- ✅ `ADMIN_TOKEN` is secure and private
- ✅ HTTPS is working (automatic on Railway)
- ✅ First backup created and tested
- ✅ Browser extension connected
- ✅ Mobile app installed (optional)

## Cost Estimate

Railway pricing:
- **Hobby Plan**: $5/month credit (requires credit card)
- **Typical Usage**: ~$3-5/month for Vaultwarden
- **Free Tier**: Available without credit card (limited hours)

Vaultwarden is very lightweight and runs efficiently on Railway's smallest tier.

## What's Next?

1. **Import existing passwords** from your current password manager
2. **Set up family sharing** if needed (invite users before disabling signups)
3. **Configure email** for password hints and recovery
4. **Schedule regular backups** (weekly recommended)
5. **Star the GitHub repo** to get update notifications

---

**Need Help?**
- Check [DEPLOY.md](DEPLOY.md) for detailed deployment info
- See [UPDATES.md](UPDATES.md) for update management
- Review [README.md](README.md) for feature documentation
- Visit Railway docs: https://docs.railway.app/
- Vaultwarden wiki: https://github.com/dani-garcia/vaultwarden/wiki
