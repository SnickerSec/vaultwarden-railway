# Monitoring Dashboard - Quick Start Guide

Get your Vaultwarden backup monitoring dashboard running in 5 minutes!

## What You Get

🎯 **Web-based dashboard** for managing backups and restores
- Beautiful, responsive UI
- One-click backup creation
- Point-and-click restore
- Real-time system monitoring
- Log viewer

## Prerequisites

- Python 3.11+ installed
- Vaultwarden backup system already set up
- 5 minutes of your time

## Installation (3 Steps)

### Step 1: Navigate to Monitor Directory

```bash
cd monitor
```

### Step 2: Run Setup Script

```bash
./setup.sh
```

**What it does:**
- Creates Python virtual environment
- Installs Flask and dependencies
- Generates secure configuration
- Asks you to set an admin password

**Choose a strong password!** You'll use this to create/restore backups.

### Step 3: Start the Dashboard

```bash
source venv/bin/activate
python app.py
```

**Output:**
```
Starting Vaultwarden Monitor on port 5000
Backup directory: /path/to/backups
Scripts directory: /path/to/scripts
 * Running on http://0.0.0.0:5000
```

## Access the Dashboard

Open your browser: **http://localhost:5000**

You should see:
- 🛡️ Vaultwarden Backup Monitor header
- System Status card
- Quick Actions buttons
- Available Backups list
- Recent logs

## First Steps

### 1. Check System Status

The **System Status** card shows:
- ✓ Total backups (number of backup files)
- ✓ Total size (storage used)
- ✓ Railway CLI status (should be green)
- ✓ PostgreSQL status (should be green)
- ✓ Latest backup info

### 2. Create Your First Backup

1. Click **"➕ Create Backup"** button
2. Enter your admin password
3. Click **"Create Backup"**
4. Wait 10-60 seconds
5. New backup appears in the list!

### 3. Verify a Backup

1. Find a backup in the list
2. Click **"✓ Verify"** button
3. Wait for verification
4. See success/failure alert
5. Check verification logs for details

### 4. Restore a Backup (When Needed)

1. Find the backup you want to restore
2. Click **"↻ Restore"** button
3. Read the warning carefully
4. Enter your admin password
5. Review options:
   - ☑️ Skip safety backup (not recommended)
   - ☑️ Force restore (skip confirmations)
6. Click **"Restore Backup"**
7. Confirm the action
8. Wait 1-5 minutes
9. Check restore logs

## Understanding the Interface

### System Status Card

```
┌─────────────────────────────┐
│ System Status          🔄   │
├─────────────────────────────┤
│ Total Backups        15     │
│ Total Size          50 MB   │
│ Railway CLI         ✓ Yes   │
│ PostgreSQL         ✓ Yes    │
│                             │
│ Latest Backup:              │
│ backup_20250113.sql.gz      │
│ 12 hours ago • 3 MB         │
└─────────────────────────────┘
```

### Backup Item

```
┌─────────────────────────────────────┐
│ vaultwarden_db_backup_20250113...   │
├─────────────────────────────────────┤
│ 📅 12 hours ago                     │
│ 💾 3.00 MB                          │
│ 🔒 600                              │
├─────────────────────────────────────┤
│ [✓ Verify]  [↻ Restore]             │
└─────────────────────────────────────┘
```

## Common Tasks

### Change Admin Password

```bash
# Generate new hash
python -c "from werkzeug.security import generate_password_hash; print(generate_password_hash('new-password'))"

# Edit .env file
nano .env

# Update this line:
MONITOR_PASSWORD_HASH=scrypt:32768:8:1$...new-hash...

# Restart dashboard
python app.py
```

### Change Port

```bash
# Edit .env file
nano .env

# Change port:
MONITOR_PORT=5001

# Restart dashboard
python app.py
```

### Run in Background

```bash
# Using nohup
nohup python app.py > monitor.log 2>&1 &

# Or using screen
screen -S monitor
python app.py
# Press Ctrl+A, then D to detach

# Reattach later
screen -r monitor
```

### Stop the Dashboard

Press **Ctrl+C** in the terminal running the dashboard.

## Troubleshooting

### "Module not found" Error

```bash
# Make sure virtual environment is activated
source venv/bin/activate

# Reinstall dependencies
pip install -r requirements.txt
```

### "Port already in use" Error

```bash
# Find what's using the port
lsof -i :5000

# Kill it or change port
export MONITOR_PORT=5001
python app.py
```

### "Invalid password" Error

```bash
# Regenerate password hash
python -c "from werkzeug.security import generate_password_hash; print(generate_password_hash('admin'))"

# Update .env with new hash
```

### "Script not found" Error

```bash
# Check scripts exist
ls -la ../scripts/

# Make them executable
chmod +x ../scripts/*.sh
```

### Dashboard Shows Red Status

**Railway CLI: Missing**
```bash
npm install -g @railway/cli
railway login
railway link
```

**PostgreSQL: Missing**
```bash
# On Ubuntu/Debian
sudo apt-get install postgresql-client

# On macOS
brew install postgresql
```

## Production Deployment

### Using Docker

```bash
# Build image
docker build -t vaultwarden-monitor .

# Run container
docker run -d \
  --name vaultwarden-monitor \
  -p 5000:5000 \
  -v $(pwd)/../backups:/backups \
  -v $(pwd)/../scripts:/scripts \
  -e MONITOR_PASSWORD_HASH="your-hash" \
  -e MONITOR_SECRET_KEY="your-secret" \
  vaultwarden-monitor
```

### Using Railway

1. Go to your Railway project
2. Click "New" → "Empty Service"
3. Name it "vaultwarden-monitor"
4. Set root directory to `/monitor`
5. Add environment variables:
   - `MONITOR_PASSWORD_HASH`
   - `MONITOR_SECRET_KEY`
   - `DATABASE_URL=${{Postgres.DATABASE_URL}}`
6. Deploy!

### Behind Reverse Proxy (HTTPS)

**Nginx:**
```nginx
server {
    listen 443 ssl;
    server_name monitor.yourdomain.com;

    location / {
        proxy_pass http://localhost:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

**Caddy:**
```
monitor.yourdomain.com {
    reverse_proxy localhost:5000
}
```

## Security Best Practices

✅ **DO:**
- Use strong admin password (12+ characters)
- Keep dependencies updated
- Run behind HTTPS in production
- Use firewall rules
- Monitor access logs
- Rotate secret key periodically

❌ **DON'T:**
- Expose to public internet without HTTPS
- Use default password "admin"
- Share admin password
- Run as root user
- Commit .env to git

## Next Steps

Once you're comfortable with the dashboard:

1. **Set up automated monitoring**
   - Check dashboard daily
   - Verify backup creation
   - Review logs weekly

2. **Test restore process**
   - Use the test workflow
   - Practice restore procedure
   - Time the process

3. **Explore advanced features**
   - API integration
   - Automated alerts
   - Custom scripts

4. **Read full documentation**
   - [MONITORING.md](MONITORING.md) - Complete guide
   - [BACKUP.md](BACKUP.md) - Backup strategies
   - [RESTORE.md](RESTORE.md) - Restore procedures

## Getting Help

**Documentation:**
- Full guide: [docs/MONITORING.md](MONITORING.md)
- API docs: [docs/MONITORING.md#api-endpoints](MONITORING.md#api-endpoints)
- Troubleshooting: [docs/MONITORING.md#troubleshooting](MONITORING.md#troubleshooting)

**Support:**
- Check application logs
- Review GitHub issues
- Create new issue with logs

## Summary

You now have a fully functional web dashboard for managing Vaultwarden backups!

**What you can do:**
- ✓ Monitor system status in real-time
- ✓ Create backups with one click
- ✓ Verify backup integrity
- ✓ Restore from any backup
- ✓ View operation logs
- ✓ All from a beautiful web interface

**Command reference:**
```bash
# Start dashboard
cd monitor
source venv/bin/activate
python app.py

# Access
http://localhost:5000

# Stop
Ctrl+C
```

Enjoy your new monitoring dashboard! 🎉

---

**Need more help?** See the [complete documentation](MONITORING.md).

**Last Updated**: January 13, 2025
