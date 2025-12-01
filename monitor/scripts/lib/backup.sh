#!/bin/bash
#
# Backup Library
# Shared functions for backup operations
#

# Prevent double-sourcing
[[ -n "$_BACKUP_SH_LOADED" ]] && return
_BACKUP_SH_LOADED=1

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

###############################################################################
# Configuration
###############################################################################

# Default backup directory (can be overridden)
export BACKUP_DIR="${BACKUP_DIR:-./backups}"
export BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"

###############################################################################
# Backup Functions
###############################################################################

# Create a database backup
# Usage: create_database_backup [output_file]
create_database_backup() {
    echo "[DEBUG] === create_database_backup START ==="
    local output_file="${1:-}"
    echo "[DEBUG] Received output_file: $output_file"

    local timestamp=$(date +%Y%m%d_%H%M%S)
    echo "[DEBUG] Generated timestamp: $timestamp"

    if [[ -z "$output_file" ]]; then
        output_file="$BACKUP_DIR/vaultwarden_db_backup_${timestamp}.sql"
        echo "[DEBUG] Using default output_file: $output_file"
    fi

    echo "[DEBUG] BACKUP_DIR: $BACKUP_DIR"
    echo "[DEBUG] Checking if BACKUP_DIR exists..."
    if [[ -d "$BACKUP_DIR" ]]; then
        echo "[DEBUG] BACKUP_DIR exists"
    else
        echo "[DEBUG] BACKUP_DIR does not exist, creating..."
    fi

    ensure_dir "$BACKUP_DIR" || {
        echo "[ERROR] Failed to create BACKUP_DIR"
        return 1
    }
    echo "[DEBUG] BACKUP_DIR ready"

    echo "[DEBUG] Creating PostgreSQL database backup..."
    echo "[DEBUG] Database URL present: $([ -n "$DATABASE_URL" ] && echo 'yes' || echo 'no')"
    echo "[DEBUG] Output file: $output_file"

    # Use direct pg_dump if DATABASE_URL is available (Railway container)
    # Otherwise use railway run command (local development)
    if [[ -n "$DATABASE_URL" ]]; then
        echo "[DEBUG] Running: pg_dump with DATABASE_URL"

        # Capture both stdout and stderr separately
        local error_file=$(mktemp)
        echo "[DEBUG] Created temp error file: $error_file"

        if pg_dump "$DATABASE_URL" > "$output_file" 2>"$error_file"; then
            echo "[SUCCESS] Database backup created: $output_file"
            rm -f "$error_file"
            echo "$output_file"
            return 0
        else
            local exit_code=$?
            echo "[ERROR] pg_dump failed with exit code: $exit_code"

            # Show error output
            if [[ -s "$error_file" ]]; then
                echo "[ERROR] pg_dump error output:"
                cat "$error_file"
            else
                echo "[ERROR] No error output from pg_dump"
            fi

            # Show last few lines of output file if it exists
            if [[ -f "$output_file" && -s "$output_file" ]]; then
                echo "[ERROR] Last lines of output file:"
                tail -5 "$output_file"
            else
                echo "[ERROR] Output file does not exist or is empty"
            fi

            rm -f "$error_file"
            return 1
        fi
    else
        if railway run pg_dump "\$DATABASE_URL" > "$output_file"; then
            print_success "Database backup created: $output_file"
            echo "$output_file"
            return 0
        else
            print_error "Database backup failed"
            return 1
        fi
    fi
}

# Compress a backup file with gzip
# Usage: compress_backup <backup_file>
compress_backup() {
    local backup_file="$1"

    print_info "compress_backup called with: $backup_file"

    if [[ ! -f "$backup_file" ]]; then
        print_error "Backup file not found: $backup_file"
        return 1
    fi

    print_info "Backup file exists, size: $(get_file_size "$backup_file" 2>/dev/null || echo 'unknown')"
    print_info "Checking if gzip is available..."

    if ! command -v gzip &> /dev/null; then
        print_error "gzip command not found!"
        return 1
    fi

    print_info "gzip found at: $(command -v gzip)"
    print_info "Compressing backup..."

    if gzip "$backup_file" 2>&1; then
        print_success "Backup compressed: ${backup_file}.gz"
        echo "${backup_file}.gz"
        return 0
    else
        local exit_code=$?
        print_error "Compression failed with exit code: $exit_code"
        return 1
    fi
}

# Clean up old backups
# Usage: cleanup_old_backups [days]
cleanup_old_backups() {
    local days="${1:-$BACKUP_RETENTION_DAYS}"

    print_info "Cleaning up backups older than $days days..."

    find "$BACKUP_DIR" -name "vaultwarden_db_backup_*.sql.gz" -mtime +"$days" -delete 2>/dev/null
    find "$BACKUP_DIR" -name "vaultwarden_db_backup_*.sql" -mtime +"$days" -delete 2>/dev/null

    print_success "Cleanup complete"
}

# List available backups
# Usage: list_backups
list_backups() {
    if [[ ! -d "$BACKUP_DIR" ]]; then
        print_warning "Backup directory not found: $BACKUP_DIR"
        return 1
    fi

    local count=0

    print_info "Available backups in $BACKUP_DIR:"
    echo ""

    while IFS= read -r -d '' backup; do
        count=$((count + 1))
        local filename=$(basename "$backup")
        local size=$(get_file_size "$backup")
        local date=$(get_file_date "$backup")

        echo "[$count] $filename"
        echo "    Size: $size | Date: $date"
        echo ""
    done < <(find "$BACKUP_DIR" -type f \( -name "*.sql.gz" -o -name "*.sql" \) -print0 | sort -rz)

    if [[ $count -eq 0 ]]; then
        print_warning "No backups found"
    else
        print_info "Total: $count backups"
    fi
}

# Verify gzip backup integrity
# Usage: verify_gzip_backup <backup_file>
verify_gzip_backup() {
    local backup_file="$1"

    if [[ ! -f "$backup_file" ]]; then
        print_error "Backup file not found: $backup_file"
        return 1
    fi

    if [[ "$backup_file" != *.gz ]]; then
        print_warning "File is not gzip compressed"
        return 0
    fi

    print_info "Verifying gzip integrity..."

    if gunzip -t "$backup_file" 2>/dev/null; then
        print_success "Gzip integrity verified"
        return 0
    else
        print_error "Gzip integrity check failed - file may be corrupted"
        return 1
    fi
}

# Create pre-operation safety backup
# Usage: create_safety_backup
create_safety_backup() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local safety_backup="$BACKUP_DIR/pre_operation_backup_${timestamp}.sql.gz"

    ensure_dir "$BACKUP_DIR"

    print_info "Creating safety backup..."

    # Use direct pg_dump if DATABASE_URL is available (Railway container)
    # Otherwise use railway run command (local development)
    if [[ -n "$DATABASE_URL" ]]; then
        if pg_dump "$DATABASE_URL" | gzip > "$safety_backup"; then
            local size=$(get_file_size "$safety_backup")
            print_success "Safety backup created: $safety_backup ($size)"
            echo "$safety_backup"
            return 0
        else
            print_error "Failed to create safety backup"
            return 1
        fi
    else
        if railway run pg_dump "\$DATABASE_URL" | gzip > "$safety_backup"; then
            local size=$(get_file_size "$safety_backup")
            print_success "Safety backup created: $safety_backup ($size)"
            echo "$safety_backup"
            return 0
        else
            print_error "Failed to create safety backup"
            return 1
        fi
    fi
}
