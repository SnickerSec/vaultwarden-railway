# Monitor Dashboard Deployment Guide

This guide will help you deploy the Vaultwarden backup monitor dashboard to Railway.

## Overview

The monitor dashboard provides a web interface to:
- View backup status and history
- Trigger manual backups
- Restore from backups
- Verify backup integrity
- Monitor system health

## Prerequisites

- Railway account
- Railway CLI installed (or use Railway web UI)
- Vaultwarden instance running on Railway
- PostgreSQL database configured

## Deployment Steps

### Option 1: Deploy via Railway CLI

1. **Navigate to monitor directory:**
   ```bash
   cd monitor
   ```

2. **Initialize Railway project (if not already done):**
   ```bash
   railway login
   railway link
   ```

3. **Set environment variables:**
   ```bash
   # Secret key for sessions
   railway variables set MONITOR_SECRET_KEY=REDACTED_MONITOR_SECRET_KEY

   # Password hash for admin access
   railway variables set MONITOR_PASSWORD_HASH='REDACTED_PASSWORD_HASH'

   # Port configuration
   railway variables set MONITOR_PORT=5000
   railway variables set MONITOR_DEBUG=false

   # Vaultwarden URL (for status monitoring)
   railway variables set VAULTWARDEN_URL=https://your-vaultwarden-instance.up.railway.app

   # Database URL (should already be set if using existing project)
   # railway variables set PUBLIC_DATABASE_URL=<your-database-url>
   ```

4. **Deploy:**
   ```bash
   railway up
   ```

### Option 2: Deploy via Railway Web UI

1. **Go to your Railway project**

2. **Create a new service:**
   - Click "New Service"
   - Select "GitHub Repo"
   - Connect your repository
   - Set root directory to `monitor`

3. **Configure environment variables** in the Railway dashboard:

   | Variable | Value |
   |----------|-------|
   | `MONITOR_SECRET_KEY` | `REDACTED_MONITOR_SECRET_KEY` |
   | `MONITOR_PASSWORD_HASH` | `REDACTED_PASSWORD_HASH` |
   | `MONITOR_PORT` | `5000` |
   | `MONITOR_DEBUG` | `false` |
   | `VAULTWARDEN_URL` | *(your Vaultwarden instance URL, e.g., https://vault.example.com)* |
   | `PUBLIC_DATABASE_URL` | *(copy from main Vaultwarden service)* |

4. **Deploy:**
   - Railway will automatically build and deploy using the Dockerfile

## Default Credentials

- **Username:** `admin`
- **Password:** `REDACTED_MONITOR_PASSWORD`

⚠️ **IMPORTANT:** Change the password immediately after first login!

### How to Change Password

1. Generate a new password hash:
   ```bash
   python3 -c "from werkzeug.security import generate_password_hash; print(generate_password_hash('YourNewPassword'))"
   ```

2. Update the `MONITOR_PASSWORD_HASH` environment variable in Railway with the new hash

3. Restart the monitor service

## Accessing the Dashboard

Once deployed, Railway will provide a URL like:
```
https://your-monitor-service.up.railway.app
```

Navigate to this URL and log in with the admin credentials.

## Features

### Dashboard Home
- Current backup status
- Last backup time
- Database size
- Quick action buttons

### Backup Management
- View backup history
- Download backups
- Trigger manual backups
- Delete old backups

### Restore Operations
- Select backup to restore
- Preview backup contents
- Perform restore with safety checks
- View restore logs

### Verification
- Verify backup integrity
- Test backup restore process
- View verification reports

## Troubleshooting

### Service Won't Start

Check Railway logs:
```bash
railway logs
```

Common issues:
- Missing environment variables
- Database connection issues
- Port conflicts

### Can't Access Dashboard

1. Verify the service is running in Railway dashboard
2. Check that the public URL is configured
3. Ensure firewall/security groups allow traffic

### Backup/Restore Not Working

1. Verify `PUBLIC_DATABASE_URL` is set correctly
2. Check database permissions
3. Review application logs for errors

## Security Notes

- The dashboard requires authentication
- Change default password immediately
- Use HTTPS (Railway provides this automatically)
- Limit access to trusted IPs if possible
- Regularly review access logs

## Maintenance

### Updating the Monitor

1. Push changes to GitHub
2. Railway will automatically rebuild and deploy

### Manual Deployment

```bash
cd monitor
railway up --detach
```

### Viewing Logs

```bash
railway logs --tail
```

## Integration with Existing Workflows

The monitor dashboard works alongside your existing GitHub Actions workflows:

- **Daily Backups:** Continue running at 3 AM UTC via GitHub Actions
- **Manual Backups:** Can be triggered via dashboard or GitHub Actions
- **Restores:** Can be performed via dashboard or restore workflow

## Next Steps

1. Deploy the monitor dashboard
2. Log in and change the default password
3. Verify backup functionality
4. Bookmark the dashboard URL
5. Set up monitoring/alerts for the service

## Support

For issues or questions:
- Check Railway logs
- Review application logs in the dashboard
- Consult the main README.md
