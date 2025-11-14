# Automated Restore System - Quick Reference

## Overview

Your Vaultwarden deployment now includes a comprehensive automated restore system that complements your existing backup infrastructure.

## What's New

### 1. Automated Restore Script
**Location:** `scripts/restore-vault.sh`

A production-ready restore script with comprehensive safety features:
- Pre-restore safety backup creation
- Backup integrity verification
- Database connection validation
- Confirmation prompts
- Post-restore verification
- Detailed logging
- Rollback instructions

**Usage:**
```bash
./scripts/restore-vault.sh backups/vaultwarden_db_backup_20250113_030000.sql.gz
```

### 2. GitHub Actions Restore Workflow
**Location:** `.github/workflows/restore-database.yml`

Web-based restore via GitHub Actions interface:
- Manual trigger with artifact selection
- Automatic pre-restore safety backup
- Post-restore data validation
- Automatic issue creation on failure
- Detailed restore logs as artifacts

**How to use:**
1. Go to Actions tab → "Restore Database"
2. Click "Run workflow"
3. Enter backup artifact name and run ID
4. Monitor progress

### 3. Backup Verification Script
**Location:** `scripts/verify-backup.sh`

Comprehensive backup integrity checker:
- Gzip integrity verification
- SQL structure validation
- Vaultwarden table detection
- Batch verification support
- Permission fixing
- Deep content analysis

**Usage:**
```bash
# List all backups
./scripts/verify-backup.sh --list

# Verify specific backup
./scripts/verify-backup.sh backups/backup.sql.gz

# Deep verification
./scripts/verify-backup.sh backups/backup.sql.gz --deep

# Verify all backups
./scripts/verify-backup.sh --all
```

### 4. Automated Restore Testing
**Location:** `.github/workflows/test-restore.yml`

Monthly automated restore testing:
- Creates test backup or uses latest
- Performs full restore
- Validates restored data
- Automatically rolls back to original state
- Generates detailed test reports
- Issues created on failure

**Schedule:** 1st of each month at 2 AM UTC

**Manual trigger:**
```bash
gh workflow run test-restore.yml
```

### 5. Comprehensive Documentation
**Location:** `docs/RESTORE.md`

Complete restore guide covering:
- All restore methods (script, GitHub Actions, manual, Railway)
- Step-by-step procedures
- Troubleshooting guide
- Rollback procedures
- Best practices
- Security considerations
- Checklists

## Quick Start Guide

### Restore from Latest Backup

```bash
# Step 1: List available backups
./scripts/verify-backup.sh --list

# Step 2: Verify backup integrity (optional but recommended)
./scripts/verify-backup.sh backups/vaultwarden_db_backup_20250113_030000.sql.gz --deep

# Step 3: Restore with safety checks
./scripts/restore-vault.sh backups/vaultwarden_db_backup_20250113_030000.sql.gz
```

### Emergency Restore (Fast)

```bash
# Skip prompts but keep safety backup
./scripts/restore-vault.sh backups/backup.sql.gz --force --verify
```

### Dry Run (Preview)

```bash
# See what would happen without making changes
./scripts/restore-vault.sh backups/backup.sql.gz --dry-run
```

## Safety Features

### Pre-Restore Safety Backup
Every restore automatically creates a safety backup before making changes:
- Stored in `backups/pre_restore_backup_TIMESTAMP.sql.gz`
- Uploaded as GitHub artifact (for Actions workflow)
- Can be used for immediate rollback
- Kept until you verify the restore

### Verification Checks
- Backup file integrity (gzip validation)
- Database connectivity
- PostgreSQL client tools availability
- Railway CLI authentication
- Post-restore data validation
- Table and user count verification

### Confirmation Prompts
- Warns if database contains data
- Requires "RESTORE" confirmation
- Shows pre-restore state
- Lists safety backup location
- Can be skipped with `--force` flag

## Rollback Procedures

### Using Pre-Restore Backup
```bash
# The restore script shows you the safety backup location
./scripts/restore-vault.sh backups/pre_restore_backup_20250113_153003.sql.gz
```

### From GitHub Actions
1. Go to restore workflow run
2. Download "pre-restore-safety-backup" artifact
3. Extract .sql.gz file
4. Restore using the script

## Testing Your Restore System

### Monthly Automated Tests
The system automatically tests restore functionality monthly:
- Non-destructive (rolls back automatically)
- Generates detailed reports
- Verifies data integrity
- Creates issues on failure

### Manual Testing
```bash
# Test with dry run
./scripts/restore-vault.sh backups/test_backup.sql.gz --dry-run

# Trigger test workflow
gh workflow run test-restore.yml
```

## File Structure

```
vaultwarden-railway/
├── scripts/
│   ├── restore-vault.sh      # Main restore script
│   ├── verify-backup.sh      # Backup verification
│   └── backup-vault.sh        # Existing backup script
├── .github/workflows/
│   ├── restore-database.yml   # Restore workflow
│   ├── test-restore.yml       # Testing workflow
│   └── backup-database.yml    # Existing backup workflow
├── docs/
│   ├── RESTORE.md             # Complete restore guide
│   ├── BACKUP.md              # Updated with restore info
│   └── RESTORE_SUMMARY.md     # This file
├── backups/                    # Backup files (gitignored)
├── restore-logs/              # Restore logs (gitignored)
└── verification-logs/         # Verification logs (gitignored)
```

## Common Use Cases

### Scenario 1: Data Corruption
```bash
# Restore from last known good backup
./scripts/verify-backup.sh --list  # Find latest
./scripts/restore-vault.sh backups/vaultwarden_db_backup_TIMESTAMP.sql.gz
```

### Scenario 2: Failed Update
```bash
# Rollback to pre-update backup
./scripts/restore-vault.sh backups/pre_update_backup_TIMESTAMP.sql.gz --force
```

### Scenario 3: Testing Changes
```bash
# Create backup before changes
./scripts/backup-vault.sh

# Make changes...

# Rollback if needed
./scripts/restore-vault.sh backups/vaultwarden_db_backup_TIMESTAMP.sql.gz
```

### Scenario 4: Migration
```bash
# Verify backup from old system
./scripts/verify-backup.sh backups/migration_backup.sql.gz --deep

# Restore to new system
./scripts/restore-vault.sh backups/migration_backup.sql.gz
```

## Monitoring and Maintenance

### Check Backup Health
```bash
# Verify all backups weekly
./scripts/verify-backup.sh --all

# Check latest backup
ls -lht backups/*.sql.gz | head -n 1
./scripts/verify-backup.sh $(ls -t backups/*.sql.gz | head -n 1) --deep
```

### Review Test Results
- Check Actions tab → "Test Restore Process"
- Download test report artifacts
- Review for any warnings or issues

### Clean Up Old Logs
```bash
# Remove logs older than 90 days
find restore-logs/ -name "*.txt" -mtime +90 -delete
find verification-logs/ -name "*.txt" -mtime +90 -delete
```

## Troubleshooting Quick Reference

| Issue | Solution |
|-------|----------|
| Railway CLI not found | `npm install -g @railway/cli` |
| Not logged into Railway | `railway login` |
| No project linked | `railway link` |
| Backup file corrupted | Try another backup or re-download artifact |
| Database connection failed | Check Railway service status |
| Restore hangs | Check network, try smaller backup |
| Permission denied | `chmod +x scripts/*.sh` |
| No tables after restore | Verify backup content, check logs |

See [docs/RESTORE.md](RESTORE.md) for detailed troubleshooting.

## Best Practices

1. **Always verify backups before restoring**
2. **Never skip the safety backup** (default behavior)
3. **Test restore process monthly** (automated)
4. **Keep safety backups for 24-48 hours** after restore
5. **Document all restore operations**
6. **Monitor automated test results**
7. **Review logs after each restore**
8. **Update documentation** when procedures change

## Key Benefits

- **Automated Safety:** Pre-restore backups prevent data loss
- **Verification:** Built-in integrity checks
- **Testing:** Monthly automated testing ensures reliability
- **Flexibility:** Multiple restore methods (script, web, manual)
- **Documentation:** Comprehensive guides and troubleshooting
- **Logging:** Detailed logs for audit and debugging
- **Rollback:** Easy rollback if restore doesn't work
- **Monitoring:** Automatic issue creation on failures

## Next Steps

1. **Test the restore system:**
   ```bash
   gh workflow run test-restore.yml
   ```

2. **Verify existing backups:**
   ```bash
   ./scripts/verify-backup.sh --all
   ```

3. **Review documentation:**
   - Read [RESTORE.md](RESTORE.md) completely
   - Familiarize yourself with all restore methods
   - Understand rollback procedures

4. **Schedule regular maintenance:**
   - Weekly: Verify backup integrity
   - Monthly: Review test results
   - Quarterly: Perform manual restore test
   - Annually: Review and update procedures

## Support

For detailed information:
- **Complete Guide:** [docs/RESTORE.md](RESTORE.md)
- **Backup Guide:** [docs/BACKUP.md](BACKUP.md)
- **Issues:** Create GitHub issue with logs

---

**System Status:**
- ✅ Automated backup system (existing)
- ✅ Automated restore system (new)
- ✅ Backup verification tools (new)
- ✅ Monthly restore testing (new)
- ✅ Comprehensive documentation (new)

Your Vaultwarden deployment now has enterprise-grade backup and restore capabilities!

---

**Created:** January 13, 2025
**Version:** 1.0.0
