#!/bin/bash
#
# Vaultwarden Database Restore Script
#
# Automates restoration of a Vaultwarden PostgreSQL database from backup
# with comprehensive safety checks.
#
# Usage:
#   ./scripts/restore-vault.sh <backup-file> [options]
#
# Options:
#   --skip-backup      Skip creating a pre-restore backup (not recommended)
#   --force            Skip confirmation prompts
#   --verify           Verify backup integrity before restore
#   --dry-run          Show what would be done without executing

set -e

# Source shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/backup.sh"

###############################################################################
# Configuration
###############################################################################

RESTORE_LOG_DIR="./restore-logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RESTORE_LOG="$RESTORE_LOG_DIR/restore_log_$TIMESTAMP.txt"

# Command line options
SKIP_BACKUP=false
FORCE=false
VERIFY=false
DRY_RUN=false
BACKUP_FILE=""

###############################################################################
# Logging with File Output
###############################################################################

# Override log function to also write to restore log
log_restore() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$RESTORE_LOG"
}

success_restore() {
    echo -e "${GREEN}✓${NC} $1" | tee -a "$RESTORE_LOG"
}

error_restore() {
    echo -e "${RED}✗ ERROR:${NC} $1" | tee -a "$RESTORE_LOG"
    exit 1
}

warning_restore() {
    echo -e "${YELLOW}⚠ WARNING:${NC} $1" | tee -a "$RESTORE_LOG"
}

###############################################################################
# Help
###############################################################################

print_usage() {
    cat << EOF
Usage: $0 <backup-file> [options]

Options:
  --skip-backup      Skip creating a pre-restore backup (not recommended)
  --force            Skip confirmation prompts
  --verify           Verify backup integrity before restore
  --dry-run          Show what would be done without executing
  -h, --help         Show this help message

Examples:
  # Basic restore with safety backup
  $0 backups/vaultwarden_db_backup_20250113_030000.sql.gz

  # Restore with verification
  $0 backups/backup.sql.gz --verify

  # Dry run to see what would happen
  $0 backups/backup.sql.gz --dry-run

  # Force restore without prompts (use with caution)
  $0 backups/backup.sql.gz --force --skip-backup
EOF
    exit 0
}

###############################################################################
# Validation Functions
###############################################################################

check_requirements() {
    log_restore "Checking system requirements..."

    check_railway_cli || error_restore "Railway CLI is not installed"
    success_restore "Railway CLI found"

    check_psql || error_restore "PostgreSQL client (psql) is not installed"
    success_restore "PostgreSQL client found"

    check_pg_dump || error_restore "PostgreSQL pg_dump is not installed"
    success_restore "pg_dump found"

    check_railway_auth || error_restore "Not logged into Railway"
    success_restore "Railway authentication verified"

    check_railway_project || error_restore "No Railway project linked"
    success_restore "Railway project linked"
}

verify_backup_file() {
    local file="$1"

    log_restore "Verifying backup file: $file"

    if [[ ! -f "$file" ]]; then
        error_restore "Backup file not found: $file"
    fi
    success_restore "Backup file exists"

    local size=$(get_file_size "$file")
    log_restore "Backup file size: $size"

    if [[ "$file" == *.gz ]]; then
        verify_gzip_backup "$file" || error_restore "Backup file is corrupted"
    fi

    local file_date=$(get_file_date "$file")
    log_restore "Backup created: $file_date"
}

get_database_info() {
    log_restore "Gathering database information..."

    local db_size=$(railway run psql "$DATABASE_URL" -t -c "SELECT pg_size_pretty(pg_database_size(current_database()));" | xargs)
    log_restore "Current database size: $db_size"

    local table_count=$(railway run psql "$DATABASE_URL" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" | xargs)
    log_restore "Current table count: $table_count"

    local row_count=$(railway run psql "$DATABASE_URL" -t -c "SELECT COUNT(*) FROM users;" 2>/dev/null | xargs || echo "0")
    log_restore "Current user count: $row_count"

    if [[ "$row_count" -gt 0 ]]; then
        warning_restore "Database contains data! This restore will REPLACE all existing data."
        return 1
    fi

    return 0
}

###############################################################################
# Restore Functions
###############################################################################

perform_restore() {
    local backup_file="$1"

    log_restore "Starting database restore from: $backup_file"

    if [[ "$DRY_RUN" == true ]]; then
        log_restore "DRY RUN - Would restore from: $backup_file"
        return 0
    fi

    # Drop existing schema and recreate
    log_restore "Dropping existing schema..."
    railway run psql "$DATABASE_URL" -c "DROP SCHEMA IF EXISTS public CASCADE; CREATE SCHEMA public;" &> /dev/null || error_restore "Failed to drop schema"
    success_restore "Schema recreated"

    # Perform the restore
    log_restore "Restoring database (this may take several minutes)..."
    local start_time=$(date +%s)

    if [[ "$backup_file" == *.gz ]]; then
        if gunzip -c "$backup_file" | railway run psql "$DATABASE_URL" > /dev/null 2>&1; then
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            success_restore "Database restored successfully in ${duration}s"
        else
            error_restore "Database restore failed"
        fi
    else
        if railway run psql "$DATABASE_URL" < "$backup_file" > /dev/null 2>&1; then
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            success_restore "Database restored successfully in ${duration}s"
        else
            error_restore "Database restore failed"
        fi
    fi
}

verify_restore() {
    log_restore "Verifying restore integrity..."

    if ! railway run psql "$DATABASE_URL" -c "SELECT 1;" &> /dev/null; then
        error_restore "Cannot connect to database after restore"
    fi
    success_restore "Database connection verified"

    local table_count=$(railway run psql "$DATABASE_URL" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" | xargs)
    log_restore "Restored table count: $table_count"

    if [[ "$table_count" -eq 0 ]]; then
        warning_restore "No tables found after restore - this may indicate a problem"
    else
        success_restore "Tables restored: $table_count"
    fi

    local user_count=$(railway run psql "$DATABASE_URL" -t -c "SELECT COUNT(*) FROM users;" 2>/dev/null | xargs || echo "0")
    if [[ "$user_count" -gt 0 ]]; then
        success_restore "User data verified: $user_count users"
    else
        warning_restore "No users found in restored database"
    fi

    local db_size=$(railway run psql "$DATABASE_URL" -t -c "SELECT pg_size_pretty(pg_database_size(current_database()));" | xargs)
    log_restore "Restored database size: $db_size"
}

###############################################################################
# Main Script
###############################################################################

main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-backup)
                SKIP_BACKUP=true
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            --verify)
                VERIFY=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -h|--help)
                print_usage
                ;;
            -*)
                error_restore "Unknown option: $1\nUse --help for usage information"
                ;;
            *)
                if [[ -z "$BACKUP_FILE" ]]; then
                    BACKUP_FILE="$1"
                else
                    error_restore "Multiple backup files specified. Please provide only one."
                fi
                shift
                ;;
        esac
    done

    # Check if backup file was provided
    if [[ -z "$BACKUP_FILE" ]]; then
        error_restore "No backup file specified.\nUse --help for usage information"
    fi

    # Create restore log directory
    ensure_dir "$RESTORE_LOG_DIR"

    print_section "Vaultwarden Database Restore Script"

    log_restore "Restore initiated at $(date)"
    log_restore "Backup file: $BACKUP_FILE"

    if [[ "$DRY_RUN" == true ]]; then
        warning_restore "DRY RUN MODE - No changes will be made"
    fi

    # Step 1: Check requirements
    check_requirements

    # Step 2: Verify backup file
    if [[ "$VERIFY" == true ]] || [[ "$DRY_RUN" == true ]]; then
        verify_backup_file "$BACKUP_FILE"
    fi

    # Step 3: Check database connection
    check_database_connection || error_restore "Cannot connect to database"
    success_restore "Database connection verified"

    # Step 4: Get database info and warn if data exists
    if ! get_database_info; then
        if [[ "$FORCE" == false ]]; then
            echo ""
            warning_restore "The database contains existing data that will be PERMANENTLY DELETED!"
            echo ""
            read -p "Are you sure you want to continue? Type 'yes' to proceed: " confirm
            if [[ "$confirm" != "yes" ]]; then
                log_restore "Restore cancelled by user"
                exit 0
            fi
        fi
    fi

    # Step 5: Create pre-restore backup
    local safety_backup=""
    if [[ "$SKIP_BACKUP" == false ]] && [[ "$DRY_RUN" == false ]]; then
        safety_backup=$(create_safety_backup)
    else
        warning_restore "Skipping pre-restore backup (not recommended)"
    fi

    # Step 6: Final confirmation
    if [[ "$FORCE" == false ]] && [[ "$DRY_RUN" == false ]]; then
        print_section "READY TO RESTORE"
        echo "Backup file: $BACKUP_FILE"
        if [[ -n "$safety_backup" ]]; then
            echo "Safety backup: $safety_backup"
        fi
        echo ""
        read -p "Proceed with restore? Type 'RESTORE' to confirm: " final_confirm
        if [[ "$final_confirm" != "RESTORE" ]]; then
            log_restore "Restore cancelled by user"
            exit 0
        fi
    fi

    # Step 7: Perform restore
    perform_restore "$BACKUP_FILE"

    # Step 8: Verify restore
    if [[ "$DRY_RUN" == false ]]; then
        verify_restore
    fi

    # Step 9: Summary
    print_section "RESTORE COMPLETE"
    success_restore "Restore completed successfully at $(date)"
    log_restore "Restore log saved to: $RESTORE_LOG"

    if [[ -n "$safety_backup" ]]; then
        log_restore "Pre-restore backup saved to: $safety_backup"
        warning_restore "Keep the safety backup until you verify the restore is working correctly"
    fi

    echo ""
    log_restore "Next steps:"
    echo "  1. Test Vaultwarden application access"
    echo "  2. Verify user login functionality"
    echo "  3. Check vault data integrity"
    echo "  4. Monitor application logs for errors"
    echo ""

    if [[ -n "$safety_backup" ]]; then
        echo "To rollback to pre-restore state:"
        echo "  ./scripts/restore-vault.sh $safety_backup"
        echo ""
    fi
}

main "$@"
