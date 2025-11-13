# Railway Deployment Guide

## Step-by-Step Deployment

### 1. Prepare Your Repository

```bash
# Initialize git repository
git init

# Add all files
git add .

# Commit
git commit -m "Initial Vaultwarden setup for Railway"

# Create GitHub repository and push
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git
git branch -M main
git push -u origin main
```

### 2. Deploy on Railway

#### Option A: Web Interface

1. Go to https://railway.app and sign in
2. Click "New Project"
3. Select "Deploy from GitHub repo"
4. Authorize Railway to access your repositories
5. Select your vaultwarden repository
6. Railway will automatically detect the Dockerfile

#### Option B: Railway CLI

```bash
# Install Railway CLI
npm install -g @railway/cli

# Login to Railway
railway login

# Link to a new project
railway init

# Deploy
railway up
```

### 3. Configure Environment Variables

In Railway dashboard:

1. Click on your service
2. Go to "Variables" tab
3. Add the following variables:

**Required Variables:**
```
DOMAIN=https://your-app.up.railway.app
ADMIN_TOKEN=GENERATE_WITH_COMMAND_BELOW
```

**Generate Admin Token:**
```bash
openssl rand -base64 48
```

**Recommended Variables:**
```
SIGNUPS_ALLOWED=true
WEBSOCKET_ENABLED=true
INVITATIONS_ALLOWED=true
LOG_LEVEL=info
```

### 4. Add PostgreSQL Database (Optional)

For production use, PostgreSQL is recommended:

1. In Railway dashboard, click "New"
2. Select "Database"
3. Choose "PostgreSQL"
4. Railway automatically injects `DATABASE_URL` to your service

### 5. Set Custom Domain (Optional)

1. Go to your service settings
2. Click "Networking"
3. Generate a Railway domain or add your custom domain
4. Update `DOMAIN` environment variable to match

### 6. Access Your Instance

1. Find your Railway URL in the dashboard
2. Click the URL to open your Vaultwarden instance
3. Create your account immediately
4. **Save your master password** - it cannot be recovered!

### 7. Secure Your Instance

After creating your account:

1. **Disable new signups:**
   ```
   SIGNUPS_ALLOWED=false
   ```

2. **Access admin panel:**
   - Go to `https://your-app.up.railway.app/admin`
   - Enter your `ADMIN_TOKEN`
   - Review settings

3. **Enable 2FA on your account:**
   - Settings → Security → Two-step Login
   - Enable Authenticator App

## Railway-Specific Configuration

### Environment Variables via CLI

```bash
# Set domain
railway variables set DOMAIN=https://your-app.up.railway.app

# Set admin token
railway variables set ADMIN_TOKEN=$(openssl rand -base64 48)

# Disable signups after account creation
railway variables set SIGNUPS_ALLOWED=false

# Optional: Configure email
railway variables set SMTP_HOST=smtp.gmail.com
railway variables set SMTP_FROM=your-email@gmail.com
railway variables set SMTP_USERNAME=your-email@gmail.com
railway variables set SMTP_PASSWORD=your-app-password
railway variables set SMTP_PORT=587
railway variables set SMTP_SECURITY=starttls
```

### View Logs

```bash
# Via CLI
railway logs

# Or in Railway dashboard:
# Click your service → View Logs
```

### Redeploy

```bash
# Push changes to trigger redeploy
git add .
git commit -m "Update configuration"
git push

# Or via CLI
railway up
```

## Connecting Bitwarden Clients

### Browser Extension

1. Install Bitwarden extension
2. Click the extension icon
3. Click settings (gear icon)
4. Enter your server URL: `https://your-app.up.railway.app`
5. Log in with your credentials

### Mobile App

1. Install Bitwarden app
2. On login screen, tap the settings icon
3. Enter Server URL: `https://your-app.up.railway.app`
4. Log in

### Desktop App

1. Install Bitwarden desktop app
2. Go to File → Settings
3. Enter Server URL: `https://your-app.up.railway.app`
4. Save and log in

### CLI

```bash
npm install -g @bitwarden/cli

bw config server https://your-app.up.railway.app
bw login
```

## Backup Strategy

### 1. Vault Export (Regular Backups)

From web vault:
- Tools → Export Vault
- Choose "JSON (Encrypted)"
- Save securely

### 2. Database Backup (PostgreSQL)

Railway automatically backs up PostgreSQL, but you can also:

```bash
# Connect to Railway PostgreSQL
railway connect postgres

# Create backup
pg_dump > backup.sql
```

### 3. Automated Backups

Consider setting up automated exports using the Bitwarden CLI:

```bash
# Login
bw login

# Export (encrypted)
bw export --format encrypted_json --output backup-$(date +%Y%m%d).json

# Add to crontab for regular backups
0 2 * * * /path/to/backup-script.sh
```

## Monitoring

### Health Checks

Railway monitors your app via the healthcheck endpoint:
- Endpoint: `/alive`
- Configured in railway.toml

### Resource Usage

Monitor in Railway dashboard:
- CPU usage
- Memory usage
- Network traffic

## Troubleshooting

### Deployment Fails

```bash
# Check logs
railway logs

# Common issues:
# - Dockerfile syntax errors
# - Missing environment variables
# - Port configuration issues
```

### Cannot Access Admin Panel

1. Verify `ADMIN_TOKEN` is set
2. Check URL: `https://your-app.up.railway.app/admin`
3. Regenerate token if needed

### Database Connection Issues

1. Ensure PostgreSQL is added to the project
2. Check `DATABASE_URL` is injected
3. Verify network connectivity in Railway dashboard

### WebSocket Issues

1. Ensure `WEBSOCKET_ENABLED=true`
2. Railway supports WebSockets by default
3. Check browser console for errors

## Cost Estimation

Railway pricing (as of 2025):
- **Hobby Plan**: $5/month credit (with credit card)
- **Pro Plan**: $20/month
- **Resource usage**: ~$0.000463/GB-hour for memory

Typical Vaultwarden usage:
- ~512MB RAM
- ~1GB storage
- Should fit within Hobby plan limits

## Security Checklist

- [ ] Strong master password created
- [ ] Admin token is secure and private
- [ ] Signups disabled after account creation
- [ ] 2FA enabled on your account
- [ ] HTTPS enabled (automatic on Railway)
- [ ] Regular vault exports scheduled
- [ ] Email configured for recovery
- [ ] PostgreSQL added for production
- [ ] Admin panel access restricted
- [ ] Domain matches Railway URL exactly

## Updates

Vaultwarden updates automatically when you rebuild:

```bash
# Trigger rebuild on Railway
git commit --allow-empty -m "Rebuild for updates"
git push
```

Railway pulls the latest `vaultwarden/server:latest` image.

## Support Resources

- Railway Docs: https://docs.railway.app/
- Railway Discord: https://discord.gg/railway
- Vaultwarden Wiki: https://github.com/dani-garcia/vaultwarden/wiki
- This setup uses official Vaultwarden Docker image
