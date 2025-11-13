#!/bin/bash
#
# Vaultwarden Backup Script
# Creates PostgreSQL database backup via Railway CLI
#

set -e

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Default backup directory
BACKUP_DIR="${BACKUP_DIR:-./backups}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/vaultwarden_db_backup_${TIMESTAMP}.sql"

# Check if Railway CLI is installed
check_railway_cli() {
    if ! command -v railway &> /dev/null; then
        print_error "Railway CLI is not installed"
        echo "Install with: npm install -g @railway/cli"
        exit 1
    fi
}

# Check if logged into Railway
check_railway_auth() {
    if ! railway whoami &> /dev/null; then
        print_error "Not logged into Railway"
        echo "Login with: railway login"
        exit 1
    fi
}

# Create database backup
backup_database() {
    print_info "Creating PostgreSQL database backup..."

    # Create backup directory
    mkdir -p "$BACKUP_DIR"

    # Perform backup via Railway
    if railway run pg_dump "\$DATABASE_URL" > "$BACKUP_FILE"; then
        print_success "Database backup created: $BACKUP_FILE"

        # Compress backup
        print_info "Compressing backup..."
        gzip "$BACKUP_FILE"
        print_success "Backup compressed: ${BACKUP_FILE}.gz"

        # Show backup size
        BACKUP_SIZE=$(du -h "${BACKUP_FILE}.gz" | cut -f1)
        print_info "Backup size: $BACKUP_SIZE"

        return 0
    else
        print_error "Database backup failed"
        return 1
    fi
}

# Clean old backups
cleanup_old_backups() {
    print_info "Cleaning up old backups (keeping last 30 days)..."
    find "$BACKUP_DIR" -name "vaultwarden_db_backup_*.sql.gz" -mtime +30 -delete
    print_success "Cleanup complete"
}

main() {
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║   Vaultwarden Backup Utility          ║"
    echo "╚════════════════════════════════════════╝"
    echo ""

    # Check prerequisites
    check_railway_cli
    check_railway_auth

    # Create database backup
    if backup_database; then
        cleanup_old_backups

        echo ""
        print_success "Backup completed successfully!"
        echo ""
        print_info "Backup Methods:"
        echo ""
        echo "1. ✓ PostgreSQL Database Backup (Completed)"
        echo "   Location: ${BACKUP_FILE}.gz"
        echo ""
        echo "2. Manual Web Vault Export (Optional):"
        echo "   - Log into your Vaultwarden web vault"
        echo "   - Go to: Tools → Export Vault"
        echo "   - Format: JSON (Encrypted)"
        echo "   - Save file to: $BACKUP_DIR/vault_export_${TIMESTAMP}.json"
        echo ""

        print_warning "Remember to:"
        echo "  ✓ Store backups securely (encrypted, off-site)"
        echo "  ✓ Test restore process periodically"
        echo "  ✓ Keep multiple backup copies"
        echo "  ✓ Backup before major updates"
        echo ""

        # Create backup log
        cat > "$BACKUP_DIR/backup_log_${TIMESTAMP}.txt" << EOF
Vaultwarden Backup Log
Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')

Database Backup:
- File: ${BACKUP_FILE}.gz
- Size: $(du -h "${BACKUP_FILE}.gz" | cut -f1)
- Status: Success

Backup Retention:
- Local: 30 days
- GitHub Actions artifacts: 90 days (automated backups)

Restore Instructions:
1. Uncompress: gunzip ${BACKUP_FILE}.gz
2. Restore: railway run psql "\$DATABASE_URL" < $BACKUP_FILE

For more info, see docs/BACKUP.md
EOF

        print_success "Backup log saved: $BACKUP_DIR/backup_log_${TIMESTAMP}.txt"
        echo ""
    else
        exit 1
    fi
}

main "$@"
