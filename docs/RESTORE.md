# Vaultwarden Database Restore Guide

This guide covers the automated restore system for your Vaultwarden database, including manual and automated restore procedures.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Restore Methods](#restore-methods)
  - [Method 1: Automated Script (Recommended)](#method-1-automated-script-recommended)
  - [Method 2: GitHub Actions Workflow](#method-2-github-actions-workflow)
  - [Method 3: Manual Restore](#method-3-manual-restore)
  - [Method 4: Railway Dashboard](#method-4-railway-dashboard)
- [Backup Verification](#backup-verification)
- [Testing Restore Process](#testing-restore-process)
- [Rollback Procedures](#rollback-procedures)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)

## Overview

The automated restore system provides multiple ways to restore your Vaultwarden database from backups:

- **Automated Script**: `scripts/restore-vault.sh` - Command-line tool with safety checks
- **GitHub Actions**: Workflow-based restore with web interface
- **Manual Restore**: Direct PostgreSQL commands
- **Railway Dashboard**: Platform-native restore capability

All restore methods include:
- Pre-restore backup creation (safety net)
- Integrity verification
- Post-restore validation
- Comprehensive logging

## Quick Start

### Restore Latest Backup

```bash
# Find latest backup
ls -lht backups/*.sql.gz | head -n 1

# Restore with safety checks
./scripts/restore-vault.sh backups/vaultwarden_db_backup_20250113_030000.sql.gz
```

### Emergency Restore

```bash
# If you need to restore immediately with minimal prompts
./scripts/restore-vault.sh backups/backup.sql.gz --force --verify
```

## Restore Methods

### Method 1: Automated Script (Recommended)

The `restore-vault.sh` script provides the safest and most user-friendly restore experience.

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

#### Examples

**Safe restore with verification:**
```bash
./scripts/restore-vault.sh backups/vaultwarden_db_backup_20250113_030000.sql.gz --verify
```

**Dry run to preview:**
```bash
./scripts/restore-vault.sh backups/backup.sql.gz --dry-run
```

**Force restore (use with caution):**
```bash
./scripts/restore-vault.sh backups/backup.sql.gz --force
```

#### What the Script Does

1. ✓ Validates system requirements (Railway CLI, PostgreSQL tools)
2. ✓ Verifies backup file integrity
3. ✓ Checks database connectivity
4. ✓ Creates pre-restore safety backup
5. ✓ Prompts for confirmation
6. ✓ Drops and recreates database schema
7. ✓ Restores from backup
8. ✓ Verifies restored data
9. ✓ Creates restore log
10. ✓ Provides rollback instructions

#### Output

```
=========================================
  Vaultwarden Database Restore Script
=========================================

[2025-01-13 15:30:00] Restore initiated at Mon Jan 13 15:30:00 UTC 2025
[2025-01-13 15:30:00] Backup file: backups/vaultwarden_db_backup_20250113_030000.sql.gz
[2025-01-13 15:30:01] Checking system requirements...
✓ Railway CLI found
✓ PostgreSQL client found
✓ pg_dump found
✓ Railway authentication verified
✓ Railway project linked
[2025-01-13 15:30:02] Checking database connection...
✓ Database connection verified
[2025-01-13 15:30:03] Creating pre-restore safety backup...
✓ Safety backup created: backups/pre_restore_backup_20250113_153003.sql.gz (2.3M)

=========================================
  READY TO RESTORE
=========================================
Backup file: backups/vaultwarden_db_backup_20250113_030000.sql.gz
Safety backup: backups/pre_restore_backup_20250113_153003.sql.gz

Proceed with restore? Type 'RESTORE' to confirm: RESTORE

[2025-01-13 15:30:10] Starting database restore...
✓ Database restored successfully in 12s
[2025-01-13 15:30:22] Verifying restore integrity...
✓ Database connection verified
✓ Tables restored: 15
✓ User data verified: 5 users

=========================================
  RESTORE COMPLETE
=========================================
```

### Method 2: GitHub Actions Workflow

Restore via the GitHub Actions web interface.

#### Steps

1. **Go to Actions Tab**
   - Navigate to your repository on GitHub
   - Click on the "Actions" tab

2. **Select Restore Workflow**
   - Click "Restore Database" workflow
   - Click "Run workflow" button

3. **Configure Restore**
   - **Backup Artifact Name**: Enter the artifact name (e.g., `vaultwarden-backup-20250113`)
   - **Backup Run ID**: Enter the workflow run ID containing the backup
   - **Skip Safety Backup**: Leave unchecked (recommended)
   - **Force Restore**: Leave unchecked unless urgent

4. **Start Restore**
   - Click "Run workflow" to start
   - Monitor progress in the workflow logs

#### Finding Backup Information

**Find Latest Backup:**
```bash
# Using GitHub CLI
gh run list --workflow="backup-database.yml" --limit 5

# Or via web interface
# Go to Actions → Backup Database → Select a successful run
```

**Get Run ID and Artifact Name:**
- Open the successful backup workflow run
- Note the run ID from the URL: `https://github.com/USER/REPO/actions/runs/RUN_ID`
- Check "Artifacts" section for artifact name

#### Workflow Features

- Automatic integrity verification
- Pre-restore safety backup (uploaded as artifact)
- Post-restore validation
- Automatic issue creation on failure
- Detailed restore log (uploaded as artifact)

### Method 3: Manual Restore

For advanced users or emergency situations.

#### Prerequisites

```bash
# Ensure you have PostgreSQL client tools
psql --version
pg_dump --version

# Ensure Railway CLI is configured
railway login
railway link
```

#### Manual Restore Steps

**1. Create Safety Backup:**
```bash
mkdir -p backups
railway run pg_dump "$DATABASE_URL" | gzip > backups/pre_restore_backup_$(date +%Y%m%d_%H%M%S).sql.gz
```

**2. Verify Backup Integrity:**
```bash
# Check gzip integrity
gunzip -t backups/your_backup.sql.gz

# View backup content (first 20 lines)
gunzip -c backups/your_backup.sql.gz | head -n 20
```

**3. Drop Existing Schema:**
```bash
railway run psql "$DATABASE_URL" -c "DROP SCHEMA IF EXISTS public CASCADE; CREATE SCHEMA public;"
```

**4. Restore from Backup:**
```bash
# For gzipped backup
gunzip -c backups/your_backup.sql.gz | railway run psql "$DATABASE_URL"

# For uncompressed backup
railway run psql "$DATABASE_URL" < backups/your_backup.sql
```

**5. Verify Restore:**
```bash
# Check table count
railway run psql "$DATABASE_URL" -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';"

# Check user count
railway run psql "$DATABASE_URL" -c "SELECT COUNT(*) FROM users;"

# Check database size
railway run psql "$DATABASE_URL" -c "SELECT pg_size_pretty(pg_database_size(current_database()));"
```

### Method 4: Railway Dashboard

Railway provides built-in backup and restore functionality.

#### Steps

1. Log into Railway Dashboard
2. Select your Vaultwarden project
3. Click on PostgreSQL service
4. Navigate to "Backups" tab
5. Select a backup point
6. Click "Restore"
7. Confirm restoration

**Note:** Railway backups are platform-managed and separate from your automated backups.

## Backup Verification

Before restoring, verify your backup file integrity.

### Using the Verification Script

```bash
# Verify a specific backup
./scripts/verify-backup.sh backups/vaultwarden_db_backup_20250113_030000.sql.gz

# List all available backups
./scripts/verify-backup.sh --list

# Verify all backups
./scripts/verify-backup.sh --all

# Deep verification (checks SQL structure)
./scripts/verify-backup.sh backups/backup.sql.gz --deep

# Fix permissions on backups
./scripts/verify-backup.sh --all --fix-permissions
```

### Verification Checks

The verification script checks:
- ✓ File existence and readability
- ✓ File size (non-zero)
- ✓ File permissions (security)
- ✓ Gzip integrity (if compressed)
- ✓ PostgreSQL dump header
- ✓ SQL structure (with --deep flag)
- ✓ Vaultwarden table presence

### Manual Verification

```bash
# Check gzip integrity
gunzip -t backups/backup.sql.gz

# Check file size
du -h backups/backup.sql.gz

# Check for PostgreSQL header
gunzip -c backups/backup.sql.gz | head -n 20 | grep "PostgreSQL database dump"

# Check for Vaultwarden tables
gunzip -c backups/backup.sql.gz | grep -E "CREATE TABLE.*(users|ciphers|folders)"
```

## Testing Restore Process

Regular testing ensures your restore process works when you need it.

### Automated Monthly Testing

The `test-restore.yml` workflow automatically tests restore functionality monthly.

**Manual Test Trigger:**
```bash
# Using GitHub CLI
gh workflow run test-restore.yml

# Or via web interface
# Go to Actions → Test Restore Process → Run workflow
```

### What the Test Does

1. Creates a fresh backup or uses latest automated backup
2. Records current database state (hash, counts, size)
3. Creates safety backup
4. Performs full restore
5. Verifies restored data
6. Rolls back to original state
7. Verifies rollback success
8. Generates test report

### Test Report

After each test, a detailed report is uploaded as an artifact:

- Pre-test database state
- Restore success/failure
- Verification results
- Rollback confirmation
- Recommendations

### Manual Testing

```bash
# Test restore in dry-run mode
./scripts/restore-vault.sh backups/test_backup.sql.gz --dry-run

# Verify backup without restoring
./scripts/verify-backup.sh backups/test_backup.sql.gz --deep
```

## Rollback Procedures

If a restore goes wrong or you need to revert changes.

### Using Pre-Restore Safety Backup

Every restore creates a safety backup by default.

**From Script Restore:**
```bash
# The script tells you the safety backup location
./scripts/restore-vault.sh backups/pre_restore_backup_20250113_153003.sql.gz
```

**From GitHub Actions Restore:**
1. Go to the restore workflow run
2. Download the "pre-restore-safety-backup" artifact
3. Extract the .sql.gz file
4. Restore using script or manual method

### Emergency Rollback

```bash
# Find the most recent pre-restore backup
ls -lht backups/pre_restore_backup_*.sql.gz | head -n 1

# Restore immediately
./scripts/restore-vault.sh backups/pre_restore_backup_TIMESTAMP.sql.gz --force
```

### Railway Rollback

If using Railway's built-in backups:
1. Go to Railway Dashboard
2. PostgreSQL service → Backups tab
3. Select backup point before restore
4. Click "Restore"

## Troubleshooting

### Common Issues and Solutions

#### "Railway CLI not found"

```bash
# Install Railway CLI
npm install -g @railway/cli

# Verify installation
railway --version
```

#### "Not logged into Railway"

```bash
railway login
```

#### "No Railway project linked"

```bash
railway link
```

#### "Cannot connect to database"

```bash
# Check database URL
railway variables

# Test connection
railway run psql "$DATABASE_URL" -c "SELECT 1;"
```

#### "Backup file corrupted"

```bash
# Verify gzip integrity
gunzip -t backups/backup.sql.gz

# Try another backup
./scripts/verify-backup.sh --list
```

#### "Restore hangs or times out"

- Check your internet connection
- Verify Railway service is running
- Try a smaller/older backup
- Check Railway dashboard for service issues

#### "Database has no tables after restore"

```bash
# Verify backup file has content
gunzip -c backups/backup.sql.gz | grep "CREATE TABLE" | wc -l

# Check for errors in restore log
cat restore-logs/restore_log_*.txt
```

#### "Permission denied on backup file"

```bash
# Fix permissions
chmod 600 backups/*.sql.gz

# Or use the verification script
./scripts/verify-backup.sh --all --fix-permissions
```

### Getting Help

If you encounter issues:

1. Check restore logs in `restore-logs/`
2. Review GitHub Actions workflow logs
3. Verify backup integrity with verification script
4. Check Railway service status
5. Review database connection settings

## Best Practices

### Before Restoring

- ✓ Always verify backup integrity first
- ✓ Create a pre-restore safety backup (default behavior)
- ✓ Test in a staging environment if possible
- ✓ Notify users of potential downtime
- ✓ Document the reason for restore
- ✓ Have a rollback plan ready

### During Restore

- ✓ Monitor the restore process
- ✓ Check logs for errors
- ✓ Don't interrupt the process
- ✓ Keep the safety backup until verification

### After Restore

- ✓ Verify data integrity
- ✓ Test user login functionality
- ✓ Check application logs
- ✓ Test critical features
- ✓ Keep safety backup for 24-48 hours
- ✓ Document the restore in logs

### Regular Maintenance

- ✓ Test restore monthly (automated)
- ✓ Verify backup integrity weekly
- ✓ Clean old backups (automated after 30 days)
- ✓ Monitor backup workflow success
- ✓ Update restore documentation
- ✓ Review and update procedures

### Security Considerations

- ✓ Restrict access to backup files (`chmod 600`)
- ✓ Don't commit backups to version control
- ✓ Encrypt sensitive backups
- ✓ Use secure transfer methods
- ✓ Audit restore operations
- ✓ Rotate backup storage credentials

### Disaster Recovery Plan

1. **Keep multiple backup locations:**
   - GitHub Actions artifacts (90 days)
   - Local backups (30 days)
   - Offsite backup (monthly)

2. **Test restore quarterly:**
   - Full production restore test
   - Document actual restore time
   - Verify all features work

3. **Document procedures:**
   - Keep restore guide accessible
   - Document database credentials location
   - List emergency contacts

4. **Maintain rollback capability:**
   - Always create safety backups
   - Keep 3 generations of backups
   - Test rollback procedures

## Restore Checklist

Use this checklist for manual restores:

- [ ] Identify correct backup file
- [ ] Verify backup integrity
- [ ] Create pre-restore safety backup
- [ ] Document current database state
- [ ] Notify users of maintenance window
- [ ] Verify Railway CLI and PostgreSQL tools
- [ ] Test database connectivity
- [ ] Perform restore
- [ ] Verify restored data
- [ ] Test application functionality
- [ ] Test user login
- [ ] Check application logs
- [ ] Monitor for errors
- [ ] Document restore completion
- [ ] Clean up temporary files
- [ ] Update incident log

## Additional Resources

- [Backup Guide](BACKUP.md) - Comprehensive backup documentation
- [Backup Setup](BACKUP_SETUP.md) - Initial backup system setup
- [Railway Documentation](https://docs.railway.app/) - Railway platform docs
- [PostgreSQL Documentation](https://www.postgresql.org/docs/) - Database reference
- [Vaultwarden Wiki](https://github.com/dani-garcia/vaultwarden/wiki) - Application documentation

## Scripts Reference

### restore-vault.sh

Location: `scripts/restore-vault.sh`

Automated restore script with safety checks.

**Usage:**
```bash
./scripts/restore-vault.sh <backup-file> [options]
```

**Features:**
- Pre-restore safety backup
- Integrity verification
- Confirmation prompts
- Post-restore validation
- Comprehensive logging

### verify-backup.sh

Location: `scripts/verify-backup.sh`

Backup verification and validation tool.

**Usage:**
```bash
./scripts/verify-backup.sh [backup-file|options]
```

**Features:**
- Gzip integrity check
- SQL structure validation
- Vaultwarden table detection
- Batch verification
- Permission fixing

## Workflow Reference

### restore-database.yml

Location: `.github/workflows/restore-database.yml`

GitHub Actions workflow for automated restore.

**Trigger:** Manual (workflow_dispatch)

**Inputs:**
- Backup artifact name
- Backup run ID
- Skip safety backup (optional)
- Force restore (optional)

**Features:**
- Web-based restore interface
- Automatic safety backup
- Post-restore verification
- Issue creation on failure

### test-restore.yml

Location: `.github/workflows/test-restore.yml`

Monthly restore testing workflow.

**Trigger:**
- Schedule (1st of month, 2 AM UTC)
- Manual (workflow_dispatch)

**Features:**
- Non-destructive testing
- Automatic rollback
- Detailed test reports
- Issue creation on failure

---

**Last Updated:** January 13, 2025
**Version:** 1.0.0
