# Railway Production Deployment Guide

## 🚀 Quick Deployment Steps

Your code has been pushed to GitHub! Now let's deploy the monitoring dashboard to Railway.

### Step 1: Access Railway Dashboard

1. Go to [Railway Dashboard](https://railway.app/dashboard)
2. Select your **vaultwarden-railway** project
3. You should see your existing services:
   - vaultwarden-railway (main app)
   - Postgres (database)

### Step 2: Add Monitoring Service

1. Click **"New"** button
2. Select **"GitHub Repo"**
3. Choose your repository: **SnickerSec/vaultwarden-railway**
4. Railway will create a new service

### Step 3: Configure the Monitoring Service

#### Service Settings:

1. **Service Name**: Rename to `vaultwarden-monitor`

2. **Root Directory**:
   - Go to service Settings → Build
   - Set **Root Directory**: `/monitor`
   - Railway will auto-detect the Dockerfile

3. **Start Command** (auto-detected):
   ```
   python app.py
   ```

4. **Health Check**:
   - Path: `/health`
   - Timeout: 100 seconds

### Step 4: Set Environment Variables

Click on the monitoring service → Variables tab → Add the following:

#### Required Variables:

```bash
# Admin Password Hash (generate below)
MONITOR_PASSWORD_HASH=<your-password-hash>

# Secret Key (use this generated one or create your own)
MONITOR_SECRET_KEY=YmHkxEF//9OwXap+A8qyX0ogMzknEST6IyIvL0N/UCw=

# Port (already configured in Dockerfile, but can override)
MONITOR_PORT=5000

# Debug mode (should be false in production)
MONITOR_DEBUG=false

# Database URL (reference from PostgreSQL service)
DATABASE_URL=${{Postgres.DATABASE_URL}}

# Or use the public URL
PUBLIC_DATABASE_URL=${{Postgres.DATABASE_PUBLIC_URL}}
```

#### Generating Password Hash:

**Option 1: Use Railway Shell**
1. Open the monitoring service
2. Click "Shell" or "Terminal"
3. Run:
```bash
python -c "from werkzeug.security import generate_password_hash; print(generate_password_hash('your-password-here'))"
```

**Option 2: Use Local Terminal** (if you have Python with werkzeug)
```bash
pip install werkzeug
python -c "from werkzeug.security import generate_password_hash; print(generate_password_hash('your-password-here'))"
```

**Option 3: Use the Deployment Script** (automated)
```bash
./scripts/deploy-to-railway.sh
```

**Copy the output** (looks like):
```
scrypt:32768:8:1$abc123xyz...
```

### Step 5: Deploy

After setting all variables:

1. **Trigger Deployment**:
   - Railway automatically deploys when you push to GitHub
   - Or click "Deploy" button manually

2. **Monitor Deployment**:
   - Watch the deployment logs
   - Look for "Starting Vaultwarden Monitor on port 5000"
   - Wait for health check to pass (green checkmark)

3. **Get the URL**:
   - Railway provides a public URL
   - Format: `https://vaultwarden-monitor-production-xxxx.up.railway.app`
   - Or add a custom domain

### Step 6: Verify Deployment

1. **Open the monitoring dashboard URL**
2. You should see the Vaultwarden Backup Monitor interface
3. **Test System Status**:
   - Check that it shows your backup statistics
   - Verify Railway CLI and PostgreSQL show as installed

4. **Test Backup Creation**:
   - Click "Create Backup"
   - Enter your admin password
   - Wait for backup to complete
   - Verify it appears in the list

5. **Test Backup Verification**:
   - Click "Verify" on a backup
   - Check that verification succeeds

## 🔧 Complete Environment Variables Reference

### Main Vaultwarden Service

```bash
# Required
DOMAIN=https://your-vaultwarden-url.up.railway.app
ADMIN_TOKEN=<your-admin-token>
DATABASE_URL=${{Postgres.DATABASE_URL}}

# Recommended
SIGNUPS_ALLOWED=false
WEBSOCKET_ENABLED=true
SHOW_PASSWORD_HINT=false

# Email (optional but recommended)
SMTP_HOST=smtp.gmail.com
SMTP_FROM=your-email@gmail.com
SMTP_PORT=587
SMTP_SECURITY=starttls
SMTP_USERNAME=your-email@gmail.com
SMTP_PASSWORD=<your-app-password>

# Rate Limiting
LOGIN_RATELIMIT_MAX_BURST=10
LOGIN_RATELIMIT_SECONDS=60
ADMIN_RATELIMIT_MAX_BURST=3
ADMIN_RATELIMIT_SECONDS=300
IP_HEADER=X-Forwarded-For
```

### Monitoring Dashboard Service

```bash
# Required
MONITOR_PASSWORD_HASH=scrypt:32768:8:1$<hash>
MONITOR_SECRET_KEY=<random-secret-key>
DATABASE_URL=${{Postgres.DATABASE_URL}}

# Optional
MONITOR_PORT=5000
MONITOR_DEBUG=false
BACKUP_DIR=../backups
SCRIPTS_DIR=../scripts
RESTORE_LOG_DIR=../restore-logs
VERIFICATION_LOG_DIR=../verification-logs
```

### GitHub Secrets (for Actions)

```bash
# Go to GitHub Repo → Settings → Secrets and variables → Actions

RAILWAY_TOKEN=<railway-api-token>
DATABASE_URL=<postgresql-public-url>
PUBLIC_DATABASE_URL=<postgresql-public-url>
```

## 📊 Service Architecture

After deployment, your Railway project will have:

```
┌─────────────────────────────────────────────┐
│         Railway Project                     │
├─────────────────────────────────────────────┤
│                                             │
│  ┌─────────────────┐                       │
│  │   PostgreSQL    │                       │
│  │   (Database)    │◄──────────┐           │
│  └─────────────────┘           │           │
│           ▲                    │           │
│           │                    │           │
│           │                    │           │
│  ┌────────┴────────┐  ┌────────┴────────┐ │
│  │  Vaultwarden    │  │   Monitoring    │ │
│  │  (Main Service) │  │   Dashboard     │ │
│  └─────────────────┘  └─────────────────┘ │
│           │                    │           │
│           │                    │           │
│  ┌────────┴────────┐  ┌────────┴────────┐ │
│  │  Public URL     │  │   Public URL    │ │
│  │  Port 80        │  │   Port 5000     │ │
│  └─────────────────┘  └─────────────────┘ │
│                                             │
└─────────────────────────────────────────────┘
```

## 🔒 Security Checklist

After deployment:

- [ ] Set strong `MONITOR_PASSWORD_HASH` (12+ characters)
- [ ] Change `ADMIN_TOKEN` for Vaultwarden
- [ ] Set `SIGNUPS_ALLOWED=false` after creating accounts
- [ ] Generate unique `MONITOR_SECRET_KEY`
- [ ] Use public DATABASE_URL for GitHub Actions
- [ ] Enable 2FA on Railway account
- [ ] Add custom domain with SSL (optional)
- [ ] Configure firewall rules (if needed)
- [ ] Review Railway access logs regularly
- [ ] Set up monitoring/alerts

## 🧪 Testing the Deployment

### Test 1: Monitoring Dashboard Access

```bash
# Test health endpoint
curl https://your-monitor-url.up.railway.app/health

# Expected response:
{"status":"healthy","timestamp":"2025-01-13T..."}
```

### Test 2: System Status API

```bash
# Get system status
curl https://your-monitor-url.up.railway.app/api/status

# Should return backup statistics
```

### Test 3: Create Backup via Dashboard

1. Open monitoring dashboard
2. Click "Create Backup"
3. Enter admin password
4. Wait for completion
5. Verify backup appears in list

### Test 4: Verify Backup

1. Select a backup
2. Click "Verify"
3. Check for success message
4. Review verification logs

### Test 5: Restore Test (use with caution)

1. **Create a safety backup first!**
2. Select an old backup
3. Click "Restore"
4. Review warnings
5. Enter password
6. Wait for completion
7. Check restore logs

## 🐛 Troubleshooting

### Monitoring Service Won't Start

**Check deployment logs:**
1. Open monitoring service in Railway
2. Click "Deployments"
3. View logs for errors

**Common issues:**
- Missing `MONITOR_PASSWORD_HASH` variable
- Missing `MONITOR_SECRET_KEY` variable
- Railway CLI not found (should be in Dockerfile)
- PostgreSQL client missing (should be in Dockerfile)

### "Invalid Password" Error

**Regenerate password hash:**
```bash
python -c "from werkzeug.security import generate_password_hash; print(generate_password_hash('new-password'))"
```
Update `MONITOR_PASSWORD_HASH` in Railway variables.

### Database Connection Failed

**Check DATABASE_URL:**
- Ensure PostgreSQL service is running
- Verify `DATABASE_URL` references PostgreSQL service
- Use format: `${{Postgres.DATABASE_URL}}`
- Or use `${{Postgres.DATABASE_PUBLIC_URL}}` for external access

### Backup Creation Fails

**Check Railway CLI:**
- Monitoring service needs Railway CLI installed (in Dockerfile)
- Verify `RAILWAY_TOKEN` is set (if needed)
- Check database connectivity

**Check scripts:**
- Ensure backup scripts are in repository
- Verify paths in environment variables
- Check script execute permissions

### Health Check Fails

**Verify health endpoint:**
```bash
curl https://your-monitor-url.up.railway.app/health
```

If it fails:
- Check service is running
- Verify port 5000 is exposed
- Check application logs
- Ensure Flask is starting correctly

## 📝 Post-Deployment Tasks

### 1. Document URLs

Save these URLs securely:
- Vaultwarden: `https://your-vaultwarden-url.up.railway.app`
- Monitoring: `https://your-monitor-url.up.railway.app`
- Admin Panel: `https://your-vaultwarden-url.up.railway.app/admin`

### 2. Save Credentials

Keep these secure:
- Vaultwarden `ADMIN_TOKEN`
- Monitoring admin password
- Master password (Vaultwarden user account)
- Railway account credentials

### 3. Set Up Monitoring

- Enable Railway notifications
- Configure GitHub Actions alerts
- Set up uptime monitoring (UptimeRobot, etc.)
- Review logs weekly

### 4. Schedule Regular Tasks

- **Daily**: Check automated backup workflow
- **Weekly**: Verify backup integrity
- **Monthly**: Test restore process
- **Quarterly**: Review security settings

### 5. Update Documentation

- Document your specific configuration
- Note any custom changes
- Keep deployment notes
- Update contact information

## 🎯 Next Steps

1. **Test the entire backup/restore workflow**
2. **Set up custom domains** (optional)
3. **Configure email notifications**
4. **Add offsite backup storage**
5. **Set up monitoring dashboards**
6. **Review security settings**
7. **Train team on restore procedures**

## 📚 Additional Resources

- [Railway Documentation](https://docs.railway.app/)
- [Monitoring Guide](docs/MONITORING.md)
- [Restore Procedures](docs/RESTORE.md)
- [Backup Strategies](docs/BACKUP.md)
- [Security Best Practices](docs/SECURITY.md)

## 🆘 Getting Help

If you encounter issues:

1. Check deployment logs in Railway
2. Review [MONITORING.md](docs/MONITORING.md) documentation
3. Check GitHub Actions workflow logs
4. Verify environment variables are set correctly
5. Test database connectivity
6. Create GitHub issue with logs

---

## 🎉 Deployment Checklist

Use this checklist to track your deployment:

- [ ] Code pushed to GitHub
- [ ] Monitoring service added in Railway
- [ ] Root directory set to `/monitor`
- [ ] Environment variables configured
- [ ] `MONITOR_PASSWORD_HASH` set
- [ ] `MONITOR_SECRET_KEY` set
- [ ] `DATABASE_URL` referenced
- [ ] Service deployed successfully
- [ ] Health check passing
- [ ] Dashboard accessible
- [ ] System status working
- [ ] Backup creation tested
- [ ] Backup verification tested
- [ ] Restore capability verified
- [ ] Documentation updated
- [ ] Credentials saved securely
- [ ] Team members notified
- [ ] Monitoring configured

**Deployment Date**: _______________
**Deployed By**: _______________
**Dashboard URL**: _______________
**Notes**: _______________

---

**Last Updated**: January 13, 2025
**Version**: 1.0.0
