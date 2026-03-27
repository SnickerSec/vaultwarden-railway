#!/bin/bash
#
# Vaultwarden Backup Verification Script
#
# Verifies the integrity and validity of backup files.
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
#   --deep             Perform deep verification (SQL syntax check)
#   --fix-permissions  Fix backup file permissions (chmod 600)

set -e

# Source shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/backup.sh"

###############################################################################
# Configuration
###############################################################################

VERIFICATION_LOG_DIR="./verification-logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
VERIFICATION_LOG="$VERIFICATION_LOG_DIR/verification_log_$TIMESTAMP.txt"

# Options
DEEP_VERIFY=false
FIX_PERMISSIONS=false
LIST_ONLY=false
VERIFY_ALL=false

###############################################################################
# Logging with File Output
###############################################################################

log_verify() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$VERIFICATION_LOG"
}

success_verify() {
    echo -e "${GREEN}✓${NC} $1" | tee -a "$VERIFICATION_LOG"
}

error_verify() {
    echo -e "${RED}✗${NC} $1" | tee -a "$VERIFICATION_LOG"
}

warning_verify() {
    echo -e "${YELLOW}⚠${NC} $1" | tee -a "$VERIFICATION_LOG"
}

###############################################################################
# Help
###############################################################################

print_usage() {
    cat << EOF
Usage: $0 [backup-file|options]

Verify backup file integrity and validity.

Options:
  <backup-file>      Path to specific backup file to verify
  --list             List all available backups
  --all              Verify all backups in the backup directory
  --deep             Perform deep verification (SQL syntax check)
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

verify_file_integrity() {
    local file="$1"

    log_verify "Verifying: $(basename "$file")"

    # Check if file exists
    if [[ ! -f "$file" ]]; then
        error_verify "File not found: $file"
        return 1
    fi

    # Check if file is readable
    if [[ ! -r "$file" ]]; then
        error_verify "File is not readable (check permissions)"
        return 1
    fi

    # Get file size
    local size=$(get_file_size "$file")
    local size_bytes=$(du -b "$file" | cut -f1)

    # Check if file is empty
    if [[ $size_bytes -eq 0 ]]; then
        error_verify "File is empty (0 bytes)"
        return 1
    fi

    success_verify "File exists and is readable ($size)"

    # Get file info
    local file_date=$(get_file_date "$file")
    local perms=$(get_file_perms "$file")

    log_verify "Created: $file_date"
    log_verify "Permissions: $perms"

    # Check permissions
    if [[ "$perms" != "-rw-------" ]] && [[ "$perms" != "-r--------" ]]; then
        warning_verify "Insecure permissions: $perms (recommended: -rw------- or -r--------)"

        if [[ "$FIX_PERMISSIONS" == true ]]; then
            chmod 600 "$file"
            success_verify "Permissions fixed to -rw-------"
        fi
    else
        success_verify "Permissions are secure"
    fi

    # Verify gzip integrity if compressed
    if [[ "$file" == *.gz ]]; then
        log_verify "Verifying gzip compression..."

        if gunzip -t "$file" 2>/dev/null; then
            success_verify "Gzip integrity verified"

            # Get uncompressed size
            local uncompressed_size=$(gunzip -l "$file" 2>/dev/null | tail -n 1 | awk '{print $2}')
            local uncompressed_human=$(numfmt --to=iec-i --suffix=B $uncompressed_size 2>/dev/null || echo "$uncompressed_size bytes")
            log_verify "Uncompressed size: $uncompressed_human"

            # Calculate compression ratio
            local ratio=$(echo "scale=1; $size_bytes * 100 / $uncompressed_size" | bc 2>/dev/null || echo "N/A")
            if [[ "$ratio" != "N/A" ]]; then
                log_verify "Compression ratio: ${ratio}%"
            fi
        else
            error_verify "Gzip integrity check FAILED - file is corrupted"
            return 1
        fi
    fi

    # Deep verification - check SQL syntax
    if [[ "$DEEP_VERIFY" == true ]]; then
        log_verify "Performing deep verification (SQL syntax check)..."

        local temp_file=$(mktemp -t vw-verify-XXXXXX)
        chmod 600 "$temp_file"

        # Extract to temp file if compressed
        if [[ "$file" == *.gz ]]; then
            if ! gunzip -c "$file" > "$temp_file" 2>/dev/null; then
                error_verify "Failed to decompress file for deep verification"
                rm -f "$temp_file"
                return 1
            fi
        else
            cp "$file" "$temp_file"
        fi

        # Check for SQL content
        if grep -q "PostgreSQL database dump" "$temp_file" 2>/dev/null; then
            success_verify "Valid PostgreSQL dump header found"
        else
            warning_verify "PostgreSQL dump header not found - may not be a valid pg_dump file"
        fi

        # Check for essential SQL commands
        local has_create=$(grep -c "CREATE TABLE" "$temp_file" 2>/dev/null || echo "0")
        local has_insert=$(grep -c "INSERT INTO" "$temp_file" 2>/dev/null || echo "0")
        local has_copy=$(grep -c "COPY .* FROM stdin" "$temp_file" 2>/dev/null || echo "0")

        log_verify "SQL structure analysis:"
        log_verify "  - CREATE TABLE statements: $has_create"
        log_verify "  - INSERT INTO statements: $has_insert"
        log_verify "  - COPY FROM statements: $has_copy"

        if [[ $has_create -eq 0 ]]; then
            warning_verify "No CREATE TABLE statements found - backup may be incomplete"
        else
            success_verify "Found $has_create table definitions"
        fi

        # Check for Vaultwarden-specific tables
        local vaultwarden_tables=("users" "ciphers" "folders" "collections" "organizations")
        log_verify "Checking for Vaultwarden tables:"

        for table in "${vaultwarden_tables[@]}"; do
            if grep -q "CREATE TABLE.*$table" "$temp_file" 2>/dev/null; then
                success_verify "  - $table table found"
            else
                warning_verify "  - $table table not found"
            fi
        done

        rm -f "$temp_file"
        success_verify "Deep verification completed"
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
                print_error "Unknown option: $1\nUse --help for usage information"
                exit 1
                ;;
            *)
                files_to_verify+=("$1")
                shift
                ;;
        esac
    done

    # Create verification log directory
    ensure_dir "$VERIFICATION_LOG_DIR"

    print_section "Vaultwarden Backup Verification"

    # Handle --list option
    if [[ "$LIST_ONLY" == true ]]; then
        list_backups
        exit 0
    fi

    log_verify "Verification started at $(date)"

    # Handle --all option
    if [[ "$VERIFY_ALL" == true ]]; then
        if [[ ! -d "$BACKUP_DIR" ]]; then
            print_error "Backup directory not found: $BACKUP_DIR"
            exit 1
        fi

        log_verify "Verifying all backups in $BACKUP_DIR..."
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

        print_section "Verification Summary"
        success_verify "Verified: $verified"
        if [[ $failed -gt 0 ]]; then
            error_verify "Failed: $failed"
        else
            echo "Failed: $failed"
        fi
        echo ""
        log_verify "Verification log: $VERIFICATION_LOG"

        exit 0
    fi

    # Verify specific files
    if [[ ${#files_to_verify[@]} -eq 0 ]]; then
        print_error "No backup file specified.\nUse --help for usage information"
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

    print_section "Verification Complete"
    success_verify "Verified: $total_verified"
    if [[ $total_failed -gt 0 ]]; then
        error_verify "Failed: $total_failed"
        exit 1
    else
        echo "Failed: $total_failed"
    fi
    echo ""
    log_verify "Verification log: $VERIFICATION_LOG"
}

main "$@"
