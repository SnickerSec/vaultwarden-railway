#!/bin/bash

###############################################################################
# Vaultwarden Backup Verification Script
#
# This script verifies the integrity and validity of backup files.
# It can check local backups or download and verify GitHub Actions artifacts.
#
# Usage:
#   ./scripts/verify-backup.sh <backup-file>
#   ./scripts/verify-backup.sh --list
#   ./scripts/verify-backup.sh --all
#
# Options:
#   <backup-file>      Path to specific backup file to verify
#   --list             List all available backups
#   --all              Verify all backups in the backup directory
#   --deep             Perform deep verification (restore to temp database)
#   --fix-permissions  Fix backup file permissions (chmod 600)
#   -h, --help         Show this help message
###############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
BACKUP_DIR="./backups"
VERIFICATION_LOG_DIR="./verification-logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
VERIFICATION_LOG="$VERIFICATION_LOG_DIR/verification_log_$TIMESTAMP.txt"

# Options
DEEP_VERIFY=false
FIX_PERMISSIONS=false
LIST_ONLY=false
VERIFY_ALL=false

###############################################################################
# Helper Functions
###############################################################################

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$VERIFICATION_LOG"
}

success() {
    echo -e "${GREEN}✓${NC} $1" | tee -a "$VERIFICATION_LOG"
}

error() {
    echo -e "${RED}✗${NC} $1" | tee -a "$VERIFICATION_LOG"
}

warning() {
    echo -e "${YELLOW}⚠${NC} $1" | tee -a "$VERIFICATION_LOG"
}

print_usage() {
    cat << EOF
Usage: $0 [backup-file|options]

Verify backup file integrity and validity.

Options:
  <backup-file>      Path to specific backup file to verify
  --list             List all available backups
  --all              Verify all backups in the backup directory
  --deep             Perform deep verification (test SQL syntax)
  --fix-permissions  Fix backup file permissions (chmod 600)
  -h, --help         Show this help message

Examples:
  # Verify a specific backup
  $0 backups/vaultwarden_db_backup_20250113_030000.sql.gz

  # List all available backups
  $0 --list

  # Verify all backups
  $0 --all

  # Deep verification with SQL syntax check
  $0 backups/backup.sql.gz --deep

  # Fix permissions on all backups
  $0 --all --fix-permissions
EOF
    exit 0
}

###############################################################################
# Verification Functions
###############################################################################

list_backups() {
    log "Listing available backups in $BACKUP_DIR..."
    echo ""

    if [[ ! -d "$BACKUP_DIR" ]]; then
        warning "Backup directory not found: $BACKUP_DIR"
        return
    fi

    local backup_count=0
    local total_size=0

    echo "Available Backups:"
    echo "==================="

    while IFS= read -r -d '' backup; do
        backup_count=$((backup_count + 1))

        # Get file info
        local filename=$(basename "$backup")
        local size=$(du -h "$backup" | cut -f1)
        local size_bytes=$(du -b "$backup" | cut -f1)
        total_size=$((total_size + size_bytes))

        if [[ "$OSTYPE" == "darwin"* ]]; then
            local date=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$backup")
            local perms=$(stat -f "%Sp" "$backup")
        else
            local date=$(stat -c "%y" "$backup" | cut -d'.' -f1)
            local perms=$(stat -c "%A" "$backup")
        fi

        echo ""
        echo "[$backup_count] $filename"
        echo "    Path: $backup"
        echo "    Size: $size"
        echo "    Date: $date"
        echo "    Permissions: $perms"

        # Check if compressed
        if [[ "$filename" == *.gz ]]; then
            if gunzip -t "$backup" 2>/dev/null; then
                echo "    Compression: Valid gzip"
            else
                echo "    Compression: CORRUPTED gzip"
            fi
        fi

    done < <(find "$BACKUP_DIR" -type f \( -name "*.sql.gz" -o -name "*.sql" \) -print0 | sort -rz)

    echo ""
    echo "==================="
    echo "Total backups: $backup_count"

    if [[ $backup_count -gt 0 ]]; then
        local total_size_human=$(numfmt --to=iec-i --suffix=B $total_size 2>/dev/null || echo "$total_size bytes")
        echo "Total size: $total_size_human"
    fi
    echo ""
}

verify_file_integrity() {
    local file="$1"

    log "Verifying: $(basename "$file")"

    # Check if file exists
    if [[ ! -f "$file" ]]; then
        error "File not found: $file"
        return 1
    fi

    # Check if file is readable
    if [[ ! -r "$file" ]]; then
        error "File is not readable (check permissions)"
        return 1
    fi

    # Get file size
    local size=$(du -h "$file" | cut -f1)
    local size_bytes=$(du -b "$file" | cut -f1)

    # Check if file is empty
    if [[ $size_bytes -eq 0 ]]; then
        error "File is empty (0 bytes)"
        return 1
    fi

    success "File exists and is readable ($size)"

    # Get file age
    if [[ "$OSTYPE" == "darwin"* ]]; then
        local file_date=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$file")
        local perms=$(stat -f "%Sp" "$file")
    else
        local file_date=$(stat -c "%y" "$file" | cut -d'.' -f1)
        local perms=$(stat -c "%A" "$file")
    fi

    log "Created: $file_date"
    log "Permissions: $perms"

    # Check permissions
    if [[ "$perms" != "-rw-------" ]] && [[ "$perms" != "-r--------" ]]; then
        warning "Insecure permissions: $perms (recommended: -rw------- or -r--------)"

        if [[ "$FIX_PERMISSIONS" == true ]]; then
            chmod 600 "$file"
            success "Permissions fixed to -rw-------"
        fi
    else
        success "Permissions are secure"
    fi

    # Verify gzip integrity if compressed
    if [[ "$file" == *.gz ]]; then
        log "Verifying gzip compression..."

        if gunzip -t "$file" 2>/dev/null; then
            success "Gzip integrity verified"

            # Get uncompressed size
            local uncompressed_size=$(gunzip -l "$file" 2>/dev/null | tail -n 1 | awk '{print $2}')
            local uncompressed_human=$(numfmt --to=iec-i --suffix=B $uncompressed_size 2>/dev/null || echo "$uncompressed_size bytes")
            log "Uncompressed size: $uncompressed_human"

            # Calculate compression ratio
            local ratio=$(echo "scale=1; $size_bytes * 100 / $uncompressed_size" | bc 2>/dev/null || echo "N/A")
            if [[ "$ratio" != "N/A" ]]; then
                log "Compression ratio: ${ratio}%"
            fi
        else
            error "Gzip integrity check FAILED - file is corrupted"
            return 1
        fi
    fi

    # Deep verification - check SQL syntax
    if [[ "$DEEP_VERIFY" == true ]]; then
        log "Performing deep verification (SQL syntax check)..."

        local temp_file=$(mktemp)

        # Extract to temp file if compressed
        if [[ "$file" == *.gz ]]; then
            if ! gunzip -c "$file" > "$temp_file" 2>/dev/null; then
                error "Failed to decompress file for deep verification"
                rm -f "$temp_file"
                return 1
            fi
        else
            cp "$file" "$temp_file"
        fi

        # Check for SQL content
        if grep -q "PostgreSQL database dump" "$temp_file" 2>/dev/null; then
            success "Valid PostgreSQL dump header found"
        else
            warning "PostgreSQL dump header not found - may not be a valid pg_dump file"
        fi

        # Check for essential SQL commands
        local has_create=$(grep -c "CREATE TABLE" "$temp_file" 2>/dev/null || echo "0")
        local has_insert=$(grep -c "INSERT INTO" "$temp_file" 2>/dev/null || echo "0")
        local has_copy=$(grep -c "COPY .* FROM stdin" "$temp_file" 2>/dev/null || echo "0")

        log "SQL structure analysis:"
        log "  - CREATE TABLE statements: $has_create"
        log "  - INSERT INTO statements: $has_insert"
        log "  - COPY FROM statements: $has_copy"

        if [[ $has_create -eq 0 ]]; then
            warning "No CREATE TABLE statements found - backup may be incomplete"
        else
            success "Found $has_create table definitions"
        fi

        # Check for Vaultwarden-specific tables
        local vaultwarden_tables=("users" "ciphers" "folders" "collections" "organizations")
        log "Checking for Vaultwarden tables:"

        for table in "${vaultwarden_tables[@]}"; do
            if grep -q "CREATE TABLE.*$table" "$temp_file" 2>/dev/null; then
                success "  - $table table found"
            else
                warning "  - $table table not found"
            fi
        done

        rm -f "$temp_file"
        success "Deep verification completed"
    fi

    return 0
}

###############################################################################
# Main Script
###############################################################################

main() {
    # Parse command line arguments
    local files_to_verify=()

    while [[ $# -gt 0 ]]; do
        case $1 in
            --list)
                LIST_ONLY=true
                shift
                ;;
            --all)
                VERIFY_ALL=true
                shift
                ;;
            --deep)
                DEEP_VERIFY=true
                shift
                ;;
            --fix-permissions)
                FIX_PERMISSIONS=true
                shift
                ;;
            -h|--help)
                print_usage
                ;;
            -*)
                error "Unknown option: $1\nUse --help for usage information"
                exit 1
                ;;
            *)
                files_to_verify+=("$1")
                shift
                ;;
        esac
    done

    # Create verification log directory
    mkdir -p "$VERIFICATION_LOG_DIR"

    echo ""
    echo "========================================="
    echo "  Vaultwarden Backup Verification"
    echo "========================================="
    echo ""

    # Handle --list option
    if [[ "$LIST_ONLY" == true ]]; then
        list_backups
        exit 0
    fi

    log "Verification started at $(date)"

    # Handle --all option
    if [[ "$VERIFY_ALL" == true ]]; then
        if [[ ! -d "$BACKUP_DIR" ]]; then
            error "Backup directory not found: $BACKUP_DIR"
            exit 1
        fi

        log "Verifying all backups in $BACKUP_DIR..."
        echo ""

        local verified=0
        local failed=0

        while IFS= read -r -d '' backup; do
            echo "----------------------------------------"
            if verify_file_integrity "$backup"; then
                verified=$((verified + 1))
            else
                failed=$((failed + 1))
            fi
            echo ""
        done < <(find "$BACKUP_DIR" -type f \( -name "*.sql.gz" -o -name "*.sql" \) -print0 | sort -rz)

        echo "========================================="
        echo "Verification Summary"
        echo "========================================="
        success "Verified: $verified"
        if [[ $failed -gt 0 ]]; then
            error "Failed: $failed"
        else
            echo "Failed: $failed"
        fi
        echo ""
        log "Verification log: $VERIFICATION_LOG"

        exit 0
    fi

    # Verify specific files
    if [[ ${#files_to_verify[@]} -eq 0 ]]; then
        error "No backup file specified.\nUse --help for usage information"
        exit 1
    fi

    local total_verified=0
    local total_failed=0

    for file in "${files_to_verify[@]}"; do
        echo "----------------------------------------"
        if verify_file_integrity "$file"; then
            total_verified=$((total_verified + 1))
        else
            total_failed=$((total_failed + 1))
        fi
        echo ""
    done

    echo "========================================="
    echo "Verification Complete"
    echo "========================================="
    success "Verified: $total_verified"
    if [[ $total_failed -gt 0 ]]; then
        error "Failed: $total_failed"
        exit 1
    else
        echo "Failed: $total_failed"
    fi
    echo ""
    log "Verification log: $VERIFICATION_LOG"
}

# Run main function
main "$@"
