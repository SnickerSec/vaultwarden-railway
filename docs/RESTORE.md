# Vaultwarden Database Restore Guide

This guide covers restoring your Vaultwarden database from backups.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Restore Methods](#restore-methods)
  - [Method 1: Automated Script (Recommended)](#method-1-automated-script-recommended)
  - [Method 2: Manual Restore](#method-2-manual-restore)
  - [Method 3: Railway Dashboard](#method-3-railway-dashboard)
- [Backup Verification](#backup-verification)
- [Testing Restore Process](#testing-restore-process)
- [Rollback Procedures](#rollback-procedures)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)

## Overview

The PostgreSQL database is only reachable on Railway's private network: public networking on the Postgres service stays **disabled**. All restore tools therefore run `psql` *inside* the Postgres container over `railway ssh` and stream the backup in.

- **Automated Script**: `scripts/restore-vault.sh`, a command-line tool with safety checks
- **Manual Restore**: the same commands, run by hand
- **Railway Dashboard**: Railway's platform-managed volume backups

Backups can be:
- `*.sql.gz.gpg`: encrypted backups from the automated pull timer (see [BACKUP.md](BACKUP.md))
- `*.sql.gz` / `*.sql`: manual or safety backups

Encrypted backups are decrypted with `~/.config/vaultwarden-backup/passphrase` (override with `BACKUP_PASSPHRASE_FILE`).

> The GitHub Actions restore workflow was removed after Railway's October 2026 security incident: it required a public database URL. Old GitHub artifact backups can only be decrypted with the `BACKUP_ENCRYPTION_PASSPHRASE` repository secret.

## Quick Start

All commands run from a checkout linked to the Railway project (`railway link`).

### Restore Latest Backup

```bash
# Find latest backup
ls -lt ~/vaultwarden-backups/ | head -n 2

# Restore with safety checks
./scripts/restore-vault.sh ~/vaultwarden-backups/vaultwarden_db_backup_20250113_030000.sql.gz.gpg --verify
```

### Emergency Restore

```bash
# If you need to restore immediately with minimal prompts
./scripts/restore-vault.sh ~/vaultwarden-backups/BACKUP.sql.gz.gpg --force --verify
```

## Restore Methods

### Method 1: Automated Script (Recommended)

#### Basic Usage

```bash
./scripts/restore-vault.sh <backup-file> [options]
```

#### Options

- `--skip-backup` - Skip creating pre-restore safety backup (not recommended)
- `--force` - Skip confirmation prompts
- `--verify` - Verify backup integrity before restore
- `--dry-run` - Show what would be done without executing
- `-h, --help` - Show help message

#### Environment

- `RAILWAY_DB_SERVICE` - Postgres service name (default: `Postgres`)
- `RAILWAY_DB_NAME` - Target database (default: the service's `PGDATABASE`, normally `railway`). Point this at a scratch database to test a restore; see [Testing Restore Process](#testing-restore-process).
- `BACKUP_DIR` - Where the safety backup is written (default: `./backups`)
- `BACKUP_PASSPHRASE_FILE` - Passphrase for `.gpg` backups

#### What the Script Does

1. ✓ Checks Railway CLI login and project link
2. ✓ Verifies the backup decrypts/decompresses and is a complete `pg_dump` (with `--verify`)
3. ✓ Checks database connectivity
4. ✓ Warns and prompts if the database already holds data
5. ✓ Creates a pre-restore safety backup
6. ✓ Prompts for final confirmation
7. ✓ Drops and recreates the `public` schema
8. ✓ Restores from backup (stops on the first SQL error)
9. ✓ Verifies restored tables and users
10. ✓ Writes a restore log to `restore-logs/` and prints rollback instructions

#### Output

```
[2026-10-24 02:17:50] Checking system requirements...
✓ Railway CLI found
✓ Railway authentication verified
✓ Railway project linked
✓ Backup file exists
✓ Backup is a complete PostgreSQL dump
✓ Database connection verified
[INFO] Creating safety backup...
[SUCCESS] Safety backup created: ./backups/pre_operation_backup_20261024_021752.sql.gz (184K)
✓ Schema recreated
✓ Database restored successfully in 2s
✓ Database connection verified
✓ Tables restored: 29
✓ User data verified: 1 users
✓ Restore completed successfully
```

### Method 2: Manual Restore

For advanced users or emergency situations. You only need the Railway CLI locally; `psql` and `pg_dump` run in the container.

```bash
railway login
railway link

# Connects over the container's local socket (works after password rotations)
PSQL='unset PGHOST PGPASSWORD; psql -h /var/run/postgresql -U postgres -d railway -v ON_ERROR_STOP=1'
```

**1. Create Safety Backup:**
```bash
mkdir -p backups
railway ssh --service Postgres -- bash -c \
  'unset PGHOST PGPASSWORD; pg_dump -h /var/run/postgresql -U postgres -d railway --no-owner --no-acl | gzip -c | base64 -w0' \
  | base64 -d > backups/pre_restore_backup_$(date +%Y%m%d_%H%M%S).sql.gz
```

**2. Verify Backup Integrity:**
```bash
gpg --decrypt --pinentry-mode loopback \
  --passphrase-file ~/.config/vaultwarden-backup/passphrase BACKUP.sql.gz.gpg \
  | gunzip -c | grep -q '^-- PostgreSQL database dump complete' && echo OK
```

**3. Drop Existing Schema:**
```bash
railway ssh --service Postgres -- bash -c "$PSQL -c 'DROP SCHEMA IF EXISTS public CASCADE; CREATE SCHEMA public;'"
```

**4. Restore from Backup:**
```bash
# Encrypted backup
gpg --decrypt --pinentry-mode loopback \
  --passphrase-file ~/.config/vaultwarden-backup/passphrase BACKUP.sql.gz.gpg \
  | gunzip -c | railway ssh --service Postgres -- bash -c "$PSQL -q"

# Gzipped backup
gunzip -c backups/your_backup.sql.gz | railway ssh --service Postgres -- bash -c "$PSQL -q"
```

**5. Verify Restore:**
```bash
echo "SELECT (SELECT COUNT(*) FROM users), (SELECT COUNT(*) FROM ciphers), pg_size_pretty(pg_database_size(current_database()));" \
  | railway ssh --service Postgres -- bash -c "$PSQL -At"
```

### Method 3: Railway Dashboard

Railway provides platform-managed volume backups:

1. Log into Railway Dashboard
2. Select your Vaultwarden project
3. Click on PostgreSQL service
4. Navigate to "Backups" tab
5. Select a backup point and click "Restore"

**Note:** Railway backups live on Railway and are separate from your pulled backups.

## Backup Verification

### Using the Verification Script

```bash
# Verify a specific backup (decrypts .gpg automatically)
./scripts/verify-backup.sh ~/vaultwarden-backups/BACKUP.sql.gz.gpg

# Deep verification (checks SQL structure and Vaultwarden tables)
./scripts/verify-backup.sh ~/vaultwarden-backups/BACKUP.sql.gz.gpg --deep

# List / verify all backups in a directory
BACKUP_DIR=~/vaultwarden-backups ./scripts/verify-backup.sh --list
BACKUP_DIR=~/vaultwarden-backups ./scripts/verify-backup.sh --all

# Fix permissions on backups
BACKUP_DIR=~/vaultwarden-backups ./scripts/verify-backup.sh --all --fix-permissions
```

### Verification Checks

- ✓ File existence, size, and permissions
- ✓ GPG decryption (for `.gpg` files)
- ✓ Gzip integrity
- ✓ PostgreSQL dump header
- ✓ SQL structure and Vaultwarden tables (with `--deep`)

## Testing Restore Process

Test restores against a **scratch database** on the same server. Production data isn't touched.

```bash
source scripts/lib/common.sh

railway_query "CREATE DATABASE vw_restore_test"

RAILWAY_DB_NAME=vw_restore_test BACKUP_DIR=$(mktemp -d) \
  ./scripts/restore-vault.sh ~/vaultwarden-backups/BACKUP.sql.gz.gpg --verify --force

# Compare with production
Q='SELECT (SELECT COUNT(*) FROM users), (SELECT COUNT(*) FROM ciphers), (SELECT COUNT(*) FROM devices)'
RAILWAY_DB_NAME=vw_restore_test railway_query "$Q"
railway_query "$Q"

railway_query "DROP DATABASE vw_restore_test"
```

Counts can differ slightly if the vault changed since the backup was taken.

Do this quarterly, and after changing the backup setup.

## Rollback Procedures

### Using Pre-Restore Safety Backup

Every script restore creates a safety backup in `BACKUP_DIR` by default, and prints the rollback command:

```bash
./scripts/restore-vault.sh backups/pre_operation_backup_TIMESTAMP.sql.gz --force
```

### Railway Rollback

1. Go to Railway Dashboard
2. PostgreSQL service → Backups tab
3. Select a backup point before the restore
4. Click "Restore"

## Troubleshooting

#### "Not logged into Railway" / "No Railway project linked"

```bash
railway login
railway link
```

#### "Cannot connect to database"

```bash
# Check SSH access to the Postgres container
railway ssh --service Postgres -- echo ok

# Check the database answers over the local socket
railway ssh --service Postgres -- bash -c 'unset PGHOST PGPASSWORD; psql -h /var/run/postgresql -U postgres -Atc "SELECT 1"'
```

If `railway ssh` asks for an SSH key, run it interactively once to register yours.

#### "Backup file is corrupted, incomplete, or can't be decrypted"

- Check the passphrase file is the one used when the backup was created
- Try another backup: `BACKUP_DIR=~/vaultwarden-backups ./scripts/verify-backup.sh --all`

#### "Database restore failed"

The restore stops at the first SQL error. Re-run the manual restore command without `-q` to see it. Your safety backup is still available.

#### "Database has no tables after restore"

```bash
./scripts/verify-backup.sh BACKUP --deep
cat restore-logs/restore_log_*.txt
```

### Getting Help

1. Check restore logs in `restore-logs/`
2. Verify backup integrity with the verification script
3. Check Railway service status
4. Open an issue in the repository

## Best Practices

### Before Restoring

- ✓ Verify backup integrity first (`--verify`)
- ✓ Keep the pre-restore safety backup (default behavior)
- ✓ Test against a scratch database if you have time
- ✓ Notify users of potential downtime

### After Restoring

- ✓ Test user login and vault sync
- ✓ Check application logs: `railway logs --service vaultwarden-railway`
- ✓ Keep the safety backup for 24-48 hours

### Security Considerations

- ✓ Keep public networking disabled on the Postgres service
- ✓ Backups and safety backups are written owner-only (`umask 077`)
- ✓ Don't commit backups to version control
- ✓ Store the backup passphrase offsite, separate from the vault itself

### Disaster Recovery Plan

1. **Keep multiple backup locations:**
   - Pulled encrypted backups (`~/vaultwarden-backups`, 30 days)
   - Offsite copy of those backups
   - Railway volume backups
   - Periodic encrypted web vault exports
2. **Test restore quarterly** against a scratch database
3. **Document** where the backup passphrase and backups are kept

## Restore Checklist

- [ ] Identify correct backup file
- [ ] Verify backup integrity
- [ ] Create pre-restore safety backup
- [ ] Notify users of maintenance window
- [ ] Perform restore
- [ ] Verify restored data
- [ ] Test application and user login
- [ ] Check application logs
- [ ] Clean up temporary files and old safety backups

## Additional Resources

- [Backup Guide](BACKUP.md) - Backup setup and documentation
- [Railway Documentation](https://docs.railway.app/) - Railway platform docs
- [PostgreSQL Documentation](https://www.postgresql.org/docs/) - Database reference
- [Vaultwarden Wiki](https://github.com/dani-garcia/vaultwarden/wiki) - Application documentation

## Scripts Reference

| Script | Purpose |
|---|---|
| `scripts/pull-backup.sh` | Automated encrypted backup (systemd timer) |
| `scripts/backup-vault.sh` | Manual unencrypted backup to `./backups` |
| `scripts/restore-vault.sh` | Restore with safety checks |
| `scripts/verify-backup.sh` | Backup verification |

---

**Last Updated:** October 24, 2026
