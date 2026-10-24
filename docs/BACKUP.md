# Vaultwarden Backup Guide

This guide covers automated and manual backup strategies for your Vaultwarden instance.

## Automated Daily Backups

Automated backups are **pulled** to a machine you control by a systemd timer running `scripts/pull-backup.sh`.

### How Automated Backups Work

The script runs `pg_dump` *inside* the Railway Postgres container over `railway ssh`, streams the result back, verifies it, and encrypts it locally with GPG.

- The database never needs a public TCP proxy. Keep public networking **disabled** on the Postgres service.
- No database credentials are stored outside Railway, and no backup credentials are stored on Railway.
- The dump connects over the container's local socket, so it keeps working after a Postgres password rotation.

> **Why not GitHub Actions?** The previous workflow connected over Railway's public TCP proxy using a database URL stored in GitHub secrets. Following Railway's October 2026 security incident, public database access has been removed, and that workflow has been retired.

**Schedule:** Daily at 3 AM (local time, ±15 min). Runs at next boot if the machine was off.

**What gets backed up:**
- Complete PostgreSQL database dump (all vault data, users, and settings)
- Verified (valid gzip + pg_dump completion marker) before it is kept
- Encrypted with GPG (AES256): `vaultwarden_db_backup_YYYYMMDD_HHMMSS.sql.gz.gpg`

**Retention:** 30 days (`BACKUP_RETENTION_DAYS`)

**On failure:** the script opens a GitHub issue in `BACKUP_ISSUE_REPO` (if set) and exits non-zero.

### Setup Requirements

On the machine that will hold the backups:

1. **Install and log in to the Railway CLI** (`railway login`). Add your SSH key if prompted; `railway ssh` must work.

2. **Create the config** (`~/.config/vaultwarden-backup/`):
   ```bash
   umask 077
   mkdir -p ~/.config/vaultwarden-backup
   openssl rand -base64 48 | tr -d '\n' > ~/.config/vaultwarden-backup/passphrase
   cat > ~/.config/vaultwarden-backup/env <<'EOF'
   RAILWAY_PROJECT_ID=<project id>
   RAILWAY_ENVIRONMENT_ID=<environment id>
   BACKUP_ISSUE_REPO=<owner>/<repo>
   EOF
   ```
   Get the IDs with `./scripts/get-railway-ids.sh` or `railway status --json`.

   **Store a copy of the passphrase somewhere other than this machine and other than this vault**: without it, backups can't be decrypted.

3. **Install the script and timer:**
   ```bash
   install -m 755 scripts/pull-backup.sh ~/.local/bin/vaultwarden-pull-backup
   install -m 644 config/systemd/vaultwarden-backup.{service,timer} ~/.config/systemd/user/
   systemctl --user daemon-reload
   systemctl --user enable --now vaultwarden-backup.timer
   loginctl enable-linger "$USER"   # run even when you're not logged in
   ```

4. **Verify Setup:**
   ```bash
   systemctl --user start vaultwarden-backup.service
   journalctl --user -u vaultwarden-backup.service -n 20
   ls -l ~/vaultwarden-backups
   ```

### Accessing Automated Backups

Backups are in `~/vaultwarden-backups` (`BACKUP_DIR`). Decrypt one with:

```bash
gpg --decrypt --pinentry-mode loopback \
  --passphrase-file ~/.config/vaultwarden-backup/passphrase \
  vaultwarden_db_backup_TIMESTAMP.sql.gz.gpg | gunzip > backup.sql
```

Backups live on a single machine, so copy them offsite too (see [Recommended Offsite](#recommended-offsite)). They're already encrypted, so they're safe to sync to cloud storage.

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

`railway run` executes locally, where the private `postgres.railway.internal` host isn't reachable, so run `pg_dump` inside the Postgres container instead:

```bash
# Backup database (run from a directory linked with `railway link`)
railway ssh --service Postgres -- bash -c \
  'unset PGHOST PGPASSWORD; pg_dump -h /var/run/postgresql -U postgres -d railway --no-owner --no-acl | gzip -c | base64 -w0' \
  | base64 -d > backup.sql.gz

# Check it's complete
zcat backup.sql.gz | grep -q '^-- PostgreSQL database dump complete' && echo OK
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
| Automated DB | Daily | 30 days | Primary backup |
| Manual Script | Weekly | 30 days | Local safety net |
| Web Export | Monthly | Permanent | Disaster recovery |
| Pre-update | Before updates | Until verified | Rollback capability |

## Restore Procedures

### Restoring from Database Backup

**From automated/manual backup file:**

Pipe the backup into `psql` inside the Postgres container:

```bash
# Optional: restore into a scratch database first to check the backup
PSQL='unset PGHOST PGPASSWORD; psql -h /var/run/postgresql -U postgres'
railway ssh --service Postgres -- bash -c "$PSQL -c 'CREATE DATABASE vw_restore_test'"

# Restore (use -d railway for production; clear the schema first, see "Restore Fails")
gpg --decrypt --pinentry-mode loopback \
  --passphrase-file ~/.config/vaultwarden-backup/passphrase \
  vaultwarden_db_backup_TIMESTAMP.sql.gz.gpg | gunzip -c \
  | railway ssh --service Postgres -- bash -c "$PSQL -d vw_restore_test -v ON_ERROR_STOP=1 -q"

# Clean up the scratch database
railway ssh --service Postgres -- bash -c "$PSQL -c 'DROP DATABASE vw_restore_test'"
```

For plain `.sql.gz` files from the manual script, replace the `gpg ... |` step with `gunzip -c file.sql.gz |`.

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

Restore into a scratch `vw_restore_test` database on the same server, as shown in [Restoring from Database Backup](#restoring-from-database-backup), then compare row counts with production:

```bash
PSQL='unset PGHOST PGPASSWORD; psql -h /var/run/postgresql -U postgres'
Q="select (select count(*) from users), (select count(*) from ciphers), (select count(*) from devices);"
for db in vw_restore_test railway; do
  echo "$Q" | railway ssh --service Postgres -- bash -c "$PSQL -d $db -At"
done
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
   - Automated daily database backups (pull timer)
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

### Automated Pull Backups
- **Location:** `~/vaultwarden-backups` on the backup machine
- **Retention:** 30 days (auto-cleanup)
- **Access:** Decrypt with the passphrase in `~/.config/vaultwarden-backup/passphrase`
- **Security:** GPG-encrypted, files and directory are owner-only (`umask 077`)

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

```bash
systemctl --user list-timers vaultwarden-backup.timer
journalctl --user -u vaultwarden-backup.service -n 50
```

Failed runs open a "Database Backup Failed" GitHub issue when `BACKUP_ISSUE_REPO` is set; enable GitHub notifications to get alerted.

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

**Check the logs:**
```bash
journalctl --user -u vaultwarden-backup.service -n 100
```

**Common issues:**
- Railway CLI logged out: run `railway login`, then `systemctl --user start vaultwarden-backup.service`
- `railway ssh` key not registered: run any `railway ssh` command interactively once
- `passphrase file not found`: recreate `~/.config/vaultwarden-backup/passphrase` (new backups only; old ones need the old passphrase)
- `dump is incomplete or invalid`: the log shows `pg_dump`'s error; check the Postgres service is running
- Timer not firing while logged out: `loginctl enable-linger "$USER"`

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
`pg_dump` runs inside the Postgres container, not locally. Make sure `--service` points at the Postgres service, not Vaultwarden.

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
PSQL='unset PGHOST PGPASSWORD; psql -h /var/run/postgresql -U postgres -d railway'

# Clear target database first (DANGER: destroys data)
railway ssh --service Postgres -- bash -c "$PSQL -c 'DROP SCHEMA public CASCADE; CREATE SCHEMA public;'"

# Then restore
gunzip -c backup.sql.gz | railway ssh --service Postgres -- bash -c "$PSQL -v ON_ERROR_STOP=1 -q"
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
- [ ] Keep public networking disabled on the Postgres service
- [ ] Install the pull backup timer and run it once
- [ ] Store the backup passphrase offsite
- [ ] Install Railway CLI locally
- [ ] Test manual backup script
- [ ] Create first web vault export
- [ ] Document backup storage locations

**Regular Maintenance:**
- [ ] Monthly: Verify automated backups running
- [ ] Monthly: Create manual web export
- [ ] Quarterly: Test restore procedure
- [ ] Quarterly: Review backup sizes
- [ ] Monthly: Copy backups offsite
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

## Support

Having issues with backups?

1. Check this guide first
2. Review `journalctl --user -u vaultwarden-backup.service`
3. Test `railway ssh --service Postgres -- echo ok`
4. Check disk space
5. Open issue in repository

---

**Remember:** Backups are only useful if you can restore from them. Test your backup and restore procedures regularly!
