# Vaultwarden Backup Guide

This guide covers automated and manual backup strategies for your Vaultwarden instance.

## Automated Daily Backups

Your deployment includes **automated daily database backups** via GitHub Actions.

### How Automated Backups Work

**Schedule:** Daily at 3 AM UTC (1 hour after update checks)

**What gets backed up:**
- Complete PostgreSQL database dump
- All vault data, users, and settings
- Compressed with gzip for efficiency

**Retention:**
- GitHub Actions artifacts: 90 days
- Local cleanup: 30 days (if using manual script)

**Workflow file:** `.github/workflows/backup-database.yml`

### Setup Requirements

To enable automated backups, you need to configure a Railway token:

1. **Generate Railway Token:**
   ```bash
   railway login
   railway token
   ```

2. **Add to GitHub Secrets:**
   - Go to your GitHub repository
   - Settings → Secrets and variables → Actions
   - Click "New repository secret"
   - Name: `RAILWAY_TOKEN`
   - Value: (paste your Railway token)
   - Click "Add secret"

3. **Verify Setup:**
   - Go to Actions tab in GitHub
   - Select "Daily Database Backup"
   - Click "Run workflow" to test
   - Check that backup completes successfully

### Accessing Automated Backups

**Via GitHub Actions:**
1. Go to your repository on GitHub
2. Click "Actions" tab
3. Select "Daily Database Backup" workflow
4. Click on a completed run
5. Download backup artifact at bottom of page

**Backup files contain:**
- Compressed SQL dump (`.sql.gz`)
- All database tables and data
- Ready for restore

## Manual Backup Methods

### Method 1: Database Backup Script (Recommended)

Use the provided backup script for quick local backups:

```bash
# Run backup script
./scripts/backup-vault.sh

# Specify custom backup directory
BACKUP_DIR=/path/to/backups ./scripts/backup-vault.sh
```

**What it does:**
- Connects to Railway PostgreSQL via CLI
- Creates compressed database dump
- Stores in `./backups` directory
- Auto-cleanup of backups older than 30 days
- Creates backup log with restore instructions

**Prerequisites:**
- Railway CLI installed: `npm install -g @railway/cli`
- Logged into Railway: `railway login`
- Project linked: `railway link`

### Method 2: Railway CLI Direct Backup

```bash
# Backup database
railway run pg_dump "$DATABASE_URL" > backup.sql

# Compress backup
gzip backup.sql

# Result: backup.sql.gz
```

### Method 3: Web Vault Export

Export your vault data directly from the web interface:

1. Log into your Vaultwarden web vault
2. Go to **Tools → Export Vault**
3. Choose format:
   - **JSON (Encrypted)** - Recommended, password protected
   - **JSON** - Unencrypted, keep secure
   - **CSV** - For importing to other services
4. Enter your master password
5. Click "Export Vault"
6. Save file securely

**Best Practice:** Use encrypted JSON format and store securely.

### Method 4: Railway Dashboard Backup

Railway provides built-in PostgreSQL backup features:

1. Go to your Railway project dashboard
2. Click on PostgreSQL service
3. Navigate to "Backups" tab
4. Railway maintains automatic backups
5. Can restore from backup points

## Backup Schedule Recommendations

| Backup Type | Frequency | Retention | Purpose |
|-------------|-----------|-----------|---------|
| Automated DB | Daily | 90 days | Primary backup |
| Manual Script | Weekly | 30 days | Local safety net |
| Web Export | Monthly | Permanent | Disaster recovery |
| Pre-update | Before updates | Until verified | Rollback capability |

## Restore Procedures

### Restoring from Database Backup

**From automated/manual backup file:**

```bash
# Uncompress backup
gunzip vaultwarden_db_backup_TIMESTAMP.sql.gz

# Restore to Railway PostgreSQL
railway run psql "$DATABASE_URL" < vaultwarden_db_backup_TIMESTAMP.sql
```

**Important:**
- Service will be temporarily unavailable during restore
- Consider creating backup before restore
- Test in staging environment if possible

### Restoring from Web Vault Export

1. Log into your Vaultwarden web vault
2. Go to **Tools → Import Data**
3. Select format (JSON/CSV/etc.)
4. Choose file to import
5. Enter master password if required
6. Click "Import Data"

**Note:** Web imports add to existing data, they don't replace it.

### Restoring from Railway Backup

1. Go to Railway project dashboard
2. Click PostgreSQL service
3. Navigate to "Backups" tab
4. Select backup point
5. Click "Restore"
6. Confirm restoration

## Backup Verification

Regularly test your backups to ensure they work:

### Test Database Backup

```bash
# Create test restore (don't affect production)
railway run --service test-instance psql "$DATABASE_URL" < backup.sql
```

### Test Web Export

1. Create new test account
2. Import backup file
3. Verify passwords are accessible
4. Test 2FA codes work
5. Check attachments load

## Backup Best Practices

1. **3-2-1 Rule:**
   - 3 copies of data
   - 2 different storage types
   - 1 offsite backup

2. **Multiple Backup Types:**
   - Automated daily database backups (GitHub)
   - Weekly manual script backups (local)
   - Monthly web exports (encrypted, offsite)

3. **Secure Storage:**
   - Encrypt backups at rest
   - Store offsite (cloud storage, external drive)
   - Restrict access to backup files
   - Never commit backups to version control

4. **Regular Testing:**
   - Test restore procedure quarterly
   - Verify backup integrity
   - Document restore process
   - Time restoration process

5. **Pre-Update Backups:**
   - Always backup before major updates
   - Keep backup until update verified
   - Document version being backed up

## Backup Storage Locations

### GitHub Actions Artifacts
- **Location:** GitHub repository Actions tab
- **Retention:** 90 days
- **Access:** Download from workflow runs
- **Security:** Private repository access required

### Local Backups
- **Location:** `./backups` directory
- **Retention:** 30 days (auto-cleanup)
- **Access:** Direct file access
- **Security:** Protect file permissions

### Recommended Offsite
- **Cloud Storage:** Google Drive, Dropbox, OneDrive
- **External Drive:** Encrypted external HDD/SSD
- **NAS:** Network attached storage
- **S3/Object Storage:** AWS S3, Backblaze B2

## Backup Monitoring

### Check Automated Backup Status

**Via GitHub:**
1. Go to Actions tab
2. Check "Daily Database Backup" workflow
3. Review recent runs
4. Failed runs create GitHub issues

**Via Email:**
- Configure GitHub notifications
- Get alerts on workflow failures

### Backup Size Monitoring

Track backup sizes to identify issues:

```bash
# Check backup directory size
du -sh backups/

# List backup files with sizes
ls -lh backups/*.gz
```

**Expected sizes:**
- Fresh instance: ~1-5 MB
- Active use (1 user, 100 passwords): ~5-20 MB
- Multiple users: Scales accordingly

Large unexpected increases may indicate:
- Data corruption
- Spam accounts (if signups enabled)
- Attachment bloat

## Troubleshooting Backups

### Automated Backup Fails

**Check GitHub Actions logs:**
1. Go to Actions tab
2. Click failed workflow run
3. Review error messages

**Common issues:**
- `RAILWAY_TOKEN` not configured
- Railway token expired
- Database connection failed
- Insufficient permissions

**Fix:**
```bash
# Generate new token
railway token

# Update GitHub secret with new token
# Settings → Secrets → RAILWAY_TOKEN → Update
```

### Manual Script Fails

**Error: "Railway CLI is not installed"**
```bash
npm install -g @railway/cli
```

**Error: "Not logged into Railway"**
```bash
railway login
```

**Error: "pg_dump: command not found"**
```bash
# Railway should provide pg_dump
# Try running via railway CLI context
railway run which pg_dump
```

### Backup File Corrupted

**Verify backup integrity:**
```bash
# Test gzip file
gunzip -t backup.sql.gz

# If OK, restore to test database
```

**If corrupted:**
- Try previous backup
- Check disk space during backup
- Verify network connection (if remote backup)

### Restore Fails

**Common issues:**
- Target database not empty
- Version mismatch
- Missing extensions
- Encoding issues

**Solution:**
```bash
# Clear target database first (DANGER: destroys data)
railway run psql "$DATABASE_URL" -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"

# Then restore
railway run psql "$DATABASE_URL" < backup.sql
```

## Security Considerations

### Backup Encryption

**Database backups (SQL dumps):**
- Not encrypted by default
- Contains sensitive vault data
- Vault items are encrypted in database
- User metadata is plaintext

**Recommendations:**
```bash
# Encrypt backup with GPG
gpg --symmetric --cipher-algo AES256 backup.sql.gz

# Decrypt when needed
gpg backup.sql.gz.gpg
```

**Web exports:**
- Use "Encrypted JSON" format
- Protected by master password
- Additional encryption recommended for storage

### Access Control

**Protect backup files:**
```bash
# Restrict file permissions
chmod 600 backups/*.gz

# Restrict directory access
chmod 700 backups/
```

**GitHub repository:**
- Keep repository private
- Limit collaborator access
- Use protected branches
- Enable 2FA for GitHub account

**Railway tokens:**
- Treat as passwords
- Never commit to version control
- Rotate periodically
- Revoke unused tokens

## Backup Checklist

**Initial Setup:**
- [ ] Configure `RAILWAY_TOKEN` in GitHub secrets
- [ ] Test automated backup workflow
- [ ] Install Railway CLI locally
- [ ] Test manual backup script
- [ ] Create first web vault export
- [ ] Document backup storage locations

**Regular Maintenance:**
- [ ] Monthly: Verify automated backups running
- [ ] Monthly: Create manual web export
- [ ] Quarterly: Test restore procedure
- [ ] Quarterly: Review backup sizes
- [ ] Annually: Rotate Railway token
- [ ] Before updates: Create backup

**Emergency Preparedness:**
- [ ] Document restore procedure
- [ ] Test restore in sandbox
- [ ] Know where all backups stored
- [ ] Have offline backup copy
- [ ] Document master password recovery

## Restore Procedures

For detailed information on restoring from backups, see the dedicated [Restore Guide](RESTORE.md).

**Quick Restore:**
```bash
./scripts/restore-vault.sh backups/vaultwarden_db_backup_TIMESTAMP.sql.gz
```

The restore system includes:
- Automated restore script with safety checks
- GitHub Actions workflow for web-based restore
- Backup verification tools
- Monthly automated restore testing
- Comprehensive rollback procedures

See [RESTORE.md](RESTORE.md) for complete restore documentation.

## Resources

- [Restore Guide](RESTORE.md) - Complete restore procedures and troubleshooting
- [Vaultwarden Backup Wiki](https://github.com/dani-garcia/vaultwarden/wiki/Backing-up-your-vault)
- [PostgreSQL Backup Guide](https://www.postgresql.org/docs/current/backup.html)
- [Railway Backup Documentation](https://docs.railway.app/databases/postgresql#backups)
- [GitHub Actions Artifacts](https://docs.github.com/en/actions/using-workflows/storing-workflow-data-as-artifacts)

## Support

Having issues with backups?

1. Check this guide first
2. Review GitHub Actions logs
3. Test Railway CLI connection
4. Check disk space
5. Verify Railway token
6. Open issue in repository

---

**Remember:** Backups are only useful if you can restore from them. Test your backup and restore procedures regularly!
