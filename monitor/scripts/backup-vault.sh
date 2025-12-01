#!/bin/bash
#
# Vaultwarden Backup Script
# Creates PostgreSQL database backup via Railway CLI
#

set -e

# Source shared libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/backup.sh"

###############################################################################
# Main Script
###############################################################################

main() {
    print_banner "Vaultwarden Backup Utility"

    # Check prerequisites only if not running in Railway container
    # Railway containers have DATABASE_URL directly available
    if [[ -z "$RAILWAY_ENVIRONMENT" && -z "$DATABASE_URL" ]]; then
        check_railway_cli || exit 1
        check_railway_auth || exit 1
    else
        print_info "Running in Railway container environment - using direct DATABASE_URL access"
    fi

    # Generate timestamp for this backup
    print_info "Generating timestamp..."
    local timestamp=$(date +%Y%m%d_%H%M%S)
    print_info "Timestamp: $timestamp"

    print_info "Backup directory: $BACKUP_DIR"
    local backup_file="$BACKUP_DIR/vaultwarden_db_backup_${timestamp}.sql"
    print_info "Target backup file: $backup_file"

    # Create database backup
    print_info "Calling create_database_backup..."
    if backup_file=$(create_database_backup "$backup_file"); then
        # Compress backup
        if compressed_file=$(compress_backup "$backup_file"); then
            # Show backup size
            local backup_size=$(get_file_size "$compressed_file")
            print_info "Backup size: $backup_size"

            # Clean old backups
            cleanup_old_backups

            echo ""
            print_success "Backup completed successfully!"
            echo ""
            print_info "Backup Methods:"
            echo ""
            echo "1. ✓ PostgreSQL Database Backup (Completed)"
            echo "   Location: $compressed_file"
            echo ""
            echo "2. Manual Web Vault Export (Optional):"
            echo "   - Log into your Vaultwarden web vault"
            echo "   - Go to: Tools → Export Vault"
            echo "   - Format: JSON (Encrypted)"
            echo "   - Save file to: $BACKUP_DIR/vault_export_${timestamp}.json"
            echo ""

            print_warning "Remember to:"
            echo "  ✓ Store backups securely (encrypted, off-site)"
            echo "  ✓ Test restore process periodically"
            echo "  ✓ Keep multiple backup copies"
            echo "  ✓ Backup before major updates"
            echo ""

            # Create backup log
            cat > "$BACKUP_DIR/backup_log_${timestamp}.txt" << EOF
Vaultwarden Backup Log
Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')

Database Backup:
- File: $compressed_file
- Size: $backup_size
- Status: Success

Backup Retention:
- Local: $BACKUP_RETENTION_DAYS days
- GitHub Actions artifacts: 90 days (automated backups)

Restore Instructions:
1. Uncompress: gunzip $compressed_file
2. Restore: railway run psql "\$DATABASE_URL" < ${compressed_file%.gz}

For more info, see docs/BACKUP.md
EOF

            print_success "Backup log saved: $BACKUP_DIR/backup_log_${timestamp}.txt"
            echo ""
        else
            exit 1
        fi
    else
        exit 1
    fi
}

main "$@"
