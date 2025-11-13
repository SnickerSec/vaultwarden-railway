# Daily Backup Setup Complete

Your Vaultwarden instance now has **automated daily backups** configured and ready to use.

## What Was Added

### 1. Automated Daily Backup Workflow
**File:** `.github/workflows/backup-database.yml`

- Runs daily at 3 AM UTC
- Creates PostgreSQL database dump
- Compresses with gzip
- Stores as GitHub Actions artifact (90-day retention)
- Sends notifications on failure
- Auto-cleans old backups (30+ days)

### 2. Enhanced Backup Script
**File:** `scripts/backup-vault.sh`

Now performs actual database backups (not just instructions):
- Connects to Railway PostgreSQL
- Creates compressed database dump
- Stores in `./backups` directory
- Auto-cleanup of old backups
- Generates backup logs with restore instructions

### 3. Comprehensive Documentation
**File:** `docs/BACKUP.md`

Complete guide covering:
- Automated backup setup
- Manual backup methods
- Restore procedures
- Best practices
- Troubleshooting
- Security considerations

### 4. Updated Configuration

**Updated `.gitignore`:**
- Excludes backup files from version control
- Prevents accidental commit of sensitive data

**Updated README.md:**
- Added backup section
- Links to backup documentation
- Quick reference for backup methods

**Updated `docs/README.md`:**
- Added backup documentation to index
- Organized maintenance section

## Setup Required

To enable automated backups, you need to add ONE GitHub secret:

### 1. Get Your DATABASE_URL from Railway

**Option A: Via Railway Dashboard**
1. Go to: https://railway.app/project/your-project/production
2. Click on your PostgreSQL service
3. Go to "Variables" tab
4. Copy the value of `DATABASE_URL`

**Option B: Via Railway CLI (locally)**
```bash
cd ~/pasman/vaultwarden-railway
railway variables | grep DATABASE_URL
```

### 2. Add Secret to GitHub

Go to: https://github.com/SnickerSec/vaultwarden-railway/settings/secrets/actions

Click "New repository secret" and add:

| Secret Name | Value |
|-------------|-------|
| `DATABASE_URL` | Your PostgreSQL connection string from Railway (starts with `postgresql://`) |

**Important:** This is sensitive data - never commit it to the repository!

### 3. Test the Setup

1. Go to: https://github.com/SnickerSec/vaultwarden-railway/actions
2. Select "Daily Database Backup"
3. Click "Run workflow"
4. Verify it completes successfully

## Backup Schedule

| Type | Frequency | Retention | Location |
|------|-----------|-----------|----------|
| Automated | Daily @ 3 AM UTC | 90 days | GitHub Actions |
| Manual script | On-demand | 30 days | Local `./backups/` |
| Web export | Manual | Permanent | Your choice |

## Using the Backup System

### Automated Backups (Recommended)

Once you add the `RAILWAY_TOKEN` secret, backups run automatically every day. No further action needed!

**To download a backup:**
1. Go to: https://github.com/SnickerSec/vaultwarden-railway/actions
2. Click "Daily Database Backup"
3. Select a completed run
4. Download artifact at bottom of page

### Manual Backup (Local)

```bash
# Run the backup script
./scripts/backup-vault.sh

# Creates: backups/vaultwarden_db_backup_TIMESTAMP.sql.gz
```

### Web Vault Export

1. Log into: https://vaultwarden-railway-production.up.railway.app
2. Go to: Tools → Export Vault
3. Choose: JSON (Encrypted)
4. Save file securely

## Restoring from Backup

### From Automated/Manual Backup:

```bash
# Uncompress
gunzip vaultwarden_db_backup_TIMESTAMP.sql.gz

# Restore
railway run psql "$DATABASE_URL" < vaultwarden_db_backup_TIMESTAMP.sql
```

### From Web Export:

1. Log into web vault
2. Go to: Tools → Import Data
3. Select your backup file
4. Enter master password
5. Click "Import Data"

## Best Practices

1. **Test your backups monthly**
   - Download a backup
   - Verify you can uncompress it
   - Document restore procedure

2. **Multiple backup types**
   - Automated daily (GitHub) - primary
   - Weekly manual (local) - safety net
   - Monthly web export - disaster recovery

3. **Offsite storage**
   - Store backups in multiple locations
   - Use encrypted cloud storage
   - Keep one offline backup

4. **Pre-update backups**
   - Always backup before major updates
   - Keep until update verified successful

## Monitoring

**Check backup status:**
- GitHub Actions tab shows recent runs
- Failed backups create GitHub issues
- Check logs for any errors

**Enable notifications:**
- GitHub Settings → Notifications
- Enable "Actions" notifications
- Get alerts on backup failures

## Documentation

For complete information, see:
- **[docs/BACKUP.md](docs/BACKUP.md)** - Full backup guide
- **[docs/UPDATES.md](docs/UPDATES.md)** - Update procedures
- **[README.md](README.md)** - Main documentation

## Support

Having issues?
1. Check [docs/BACKUP.md](docs/BACKUP.md) troubleshooting section
2. Verify `RAILWAY_TOKEN` is set correctly
3. Check GitHub Actions logs
4. Test Railway CLI connection locally

---

**Your data is now protected with automated daily backups!**

Remember: Backups are only useful if you test them. Verify your backup and restore procedures regularly.
