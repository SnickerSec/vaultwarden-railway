#!/bin/bash

###############################################################################
# Vaultwarden Database Restore Script
#
# This script automates the restoration of a Vaultwarden PostgreSQL database
# from a backup file with comprehensive safety checks.
#
# Usage:
#   ./scripts/restore-vault.sh <backup-file> [options]
#
# Options:
#   --skip-backup      Skip creating a pre-restore backup (not recommended)
#   --force            Skip confirmation prompts
#   --verify           Verify backup integrity before restore
#   --dry-run          Show what would be done without executing
#
# Requirements:
#   - Railway CLI installed and configured
#   - Valid backup file (.sql or .sql.gz)
#   - PostgreSQL client tools (psql, pg_dump)
###############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BACKUP_DIR="./backups"
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
# Helper Functions
###############################################################################

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$RESTORE_LOG"
}

success() {
    echo -e "${GREEN}✓${NC} $1" | tee -a "$RESTORE_LOG"
}

error() {
    echo -e "${RED}✗ ERROR:${NC} $1" | tee -a "$RESTORE_LOG"
    exit 1
}

warning() {
    echo -e "${YELLOW}⚠ WARNING:${NC} $1" | tee -a "$RESTORE_LOG"
}

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
    log "Checking system requirements..."

    # Check for Railway CLI
    if ! command -v railway &> /dev/null; then
        error "Railway CLI is not installed. Install it with: npm install -g @railway/cli"
    fi
    success "Railway CLI found"

    # Check for psql
    if ! command -v psql &> /dev/null; then
        error "PostgreSQL client (psql) is not installed"
    fi
    success "PostgreSQL client found"

    # Check for pg_dump
    if ! command -v pg_dump &> /dev/null; then
        error "PostgreSQL pg_dump is not installed"
    fi
    success "pg_dump found"

    # Check Railway authentication
    if ! railway whoami &> /dev/null; then
        error "Not logged into Railway. Run: railway login"
    fi
    success "Railway authentication verified"

    # Check if project is linked
    if ! railway status &> /dev/null; then
        error "No Railway project linked. Run: railway link"
    fi
    success "Railway project linked"
}

verify_backup_file() {
    local file="$1"

    log "Verifying backup file: $file"

    # Check if file exists
    if [[ ! -f "$file" ]]; then
        error "Backup file not found: $file"
    fi
    success "Backup file exists"

    # Check file size
    local size=$(du -h "$file" | cut -f1)
    log "Backup file size: $size"

    if [[ "$file" == *.gz ]]; then
        log "Checking gzip integrity..."
        if ! gunzip -t "$file" 2>/dev/null; then
            error "Backup file is corrupted (gzip integrity check failed)"
        fi
        success "Gzip integrity verified"
    fi

    # Get file age
    if [[ "$OSTYPE" == "darwin"* ]]; then
        local file_date=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$file")
    else
        local file_date=$(stat -c "%y" "$file" | cut -d'.' -f1)
    fi
    log "Backup created: $file_date"
}

check_database_connection() {
    log "Checking database connection..."

    if ! railway run psql "$DATABASE_URL" -c "SELECT version();" &> /dev/null; then
        error "Cannot connect to database"
    fi
    success "Database connection verified"
}

get_database_info() {
    log "Gathering database information..."

    # Get database size
    local db_size=$(railway run psql "$DATABASE_URL" -t -c "SELECT pg_size_pretty(pg_database_size(current_database()));" | xargs)
    log "Current database size: $db_size"

    # Get table count
    local table_count=$(railway run psql "$DATABASE_URL" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" | xargs)
    log "Current table count: $table_count"

    # Check if database has data
    local row_count=$(railway run psql "$DATABASE_URL" -t -c "SELECT COUNT(*) FROM users;" 2>/dev/null | xargs || echo "0")
    log "Current user count: $row_count"

    if [[ "$row_count" -gt 0 ]]; then
        warning "Database contains data! This restore will REPLACE all existing data."
        return 1
    fi

    return 0
}

###############################################################################
# Backup Functions
###############################################################################

create_pre_restore_backup() {
    log "Creating pre-restore safety backup..."

    mkdir -p "$BACKUP_DIR"

    local safety_backup="$BACKUP_DIR/pre_restore_backup_$TIMESTAMP.sql.gz"

    if railway run pg_dump "$DATABASE_URL" | gzip > "$safety_backup"; then
        local size=$(du -h "$safety_backup" | cut -f1)
        success "Safety backup created: $safety_backup ($size)"
        echo "$safety_backup"
    else
        error "Failed to create safety backup"
    fi
}

###############################################################################
# Restore Functions
###############################################################################

perform_restore() {
    local backup_file="$1"

    log "Starting database restore from: $backup_file"

    # Determine if file is compressed
    local restore_cmd=""
    if [[ "$backup_file" == *.gz ]]; then
        log "Decompressing and restoring gzipped backup..."
        restore_cmd="gunzip -c '$backup_file' | railway run psql \"\$DATABASE_URL\""
    else
        log "Restoring uncompressed backup..."
        restore_cmd="railway run psql \"\$DATABASE_URL\" < '$backup_file'"
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log "DRY RUN - Would execute: $restore_cmd"
        return 0
    fi

    # Drop existing schema and recreate (clean slate)
    log "Dropping existing schema..."
    railway run psql "$DATABASE_URL" -c "DROP SCHEMA IF EXISTS public CASCADE; CREATE SCHEMA public;" &> /dev/null || error "Failed to drop schema"
    success "Schema recreated"

    # Perform the restore
    log "Restoring database (this may take several minutes)..."
    local start_time=$(date +%s)

    if [[ "$backup_file" == *.gz ]]; then
        if gunzip -c "$backup_file" | railway run psql "$DATABASE_URL" > /dev/null 2>&1; then
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            success "Database restored successfully in ${duration}s"
        else
            error "Database restore failed"
        fi
    else
        if railway run psql "$DATABASE_URL" < "$backup_file" > /dev/null 2>&1; then
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            success "Database restored successfully in ${duration}s"
        else
            error "Database restore failed"
        fi
    fi
}

verify_restore() {
    log "Verifying restore integrity..."

    # Check database connection
    if ! railway run psql "$DATABASE_URL" -c "SELECT 1;" &> /dev/null; then
        error "Cannot connect to database after restore"
    fi
    success "Database connection verified"

    # Get post-restore statistics
    local table_count=$(railway run psql "$DATABASE_URL" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" | xargs)
    log "Restored table count: $table_count"

    if [[ "$table_count" -eq 0 ]]; then
        warning "No tables found after restore - this may indicate a problem"
    else
        success "Tables restored: $table_count"
    fi

    # Check if users table exists and has data
    local user_count=$(railway run psql "$DATABASE_URL" -t -c "SELECT COUNT(*) FROM users;" 2>/dev/null | xargs || echo "0")
    if [[ "$user_count" -gt 0 ]]; then
        success "User data verified: $user_count users"
    else
        warning "No users found in restored database"
    fi

    # Get database size
    local db_size=$(railway run psql "$DATABASE_URL" -t -c "SELECT pg_size_pretty(pg_database_size(current_database()));" | xargs)
    log "Restored database size: $db_size"
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
                error "Unknown option: $1\nUse --help for usage information"
                ;;
            *)
                if [[ -z "$BACKUP_FILE" ]]; then
                    BACKUP_FILE="$1"
                else
                    error "Multiple backup files specified. Please provide only one."
                fi
                shift
                ;;
        esac
    done

    # Check if backup file was provided
    if [[ -z "$BACKUP_FILE" ]]; then
        error "No backup file specified.\nUse --help for usage information"
    fi

    # Create restore log directory
    mkdir -p "$RESTORE_LOG_DIR"

    # Print banner
    echo ""
    echo "========================================="
    echo "  Vaultwarden Database Restore Script"
    echo "========================================="
    echo ""

    log "Restore initiated at $(date)"
    log "Backup file: $BACKUP_FILE"

    if [[ "$DRY_RUN" == true ]]; then
        warning "DRY RUN MODE - No changes will be made"
    fi

    # Step 1: Check requirements
    check_requirements

    # Step 2: Verify backup file
    if [[ "$VERIFY" == true ]] || [[ "$DRY_RUN" == true ]]; then
        verify_backup_file "$BACKUP_FILE"
    fi

    # Step 3: Check database connection
    check_database_connection

    # Step 4: Get database info and warn if data exists
    if ! get_database_info; then
        if [[ "$FORCE" == false ]]; then
            echo ""
            warning "The database contains existing data that will be PERMANENTLY DELETED!"
            echo ""
            read -p "Are you sure you want to continue? Type 'yes' to proceed: " confirm
            if [[ "$confirm" != "yes" ]]; then
                log "Restore cancelled by user"
                exit 0
            fi
        fi
    fi

    # Step 5: Create pre-restore backup
    local safety_backup=""
    if [[ "$SKIP_BACKUP" == false ]] && [[ "$DRY_RUN" == false ]]; then
        safety_backup=$(create_pre_restore_backup)
    else
        warning "Skipping pre-restore backup (not recommended)"
    fi

    # Step 6: Final confirmation
    if [[ "$FORCE" == false ]] && [[ "$DRY_RUN" == false ]]; then
        echo ""
        echo "========================================="
        echo "  READY TO RESTORE"
        echo "========================================="
        echo "Backup file: $BACKUP_FILE"
        if [[ -n "$safety_backup" ]]; then
            echo "Safety backup: $safety_backup"
        fi
        echo ""
        read -p "Proceed with restore? Type 'RESTORE' to confirm: " final_confirm
        if [[ "$final_confirm" != "RESTORE" ]]; then
            log "Restore cancelled by user"
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
    echo ""
    echo "========================================="
    echo "  RESTORE COMPLETE"
    echo "========================================="
    success "Restore completed successfully at $(date)"
    log "Restore log saved to: $RESTORE_LOG"

    if [[ -n "$safety_backup" ]]; then
        log "Pre-restore backup saved to: $safety_backup"
        warning "Keep the safety backup until you verify the restore is working correctly"
    fi

    echo ""
    log "Next steps:"
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

# Run main function
main "$@"
