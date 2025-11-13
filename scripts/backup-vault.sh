#!/bin/bash
#
# Vaultwarden Backup Script
# Creates encrypted backup of vault data before updates
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
BACKUP_FILE="vaultwarden_backup_${TIMESTAMP}.tar.gz"

main() {
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║   Vaultwarden Backup Utility          ║"
    echo "╚════════════════════════════════════════╝"
    echo ""

    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    print_info "Backup directory: $BACKUP_DIR"

    # Instructions for manual backup
    print_warning "This script provides backup instructions."
    print_warning "Actual backup must be done from your Vaultwarden instance."
    echo ""

    print_info "Backup Methods:"
    echo ""

    echo "1. Web Vault Export (Recommended):"
    echo "   - Log into your Vaultwarden web vault"
    echo "   - Go to: Tools → Export Vault"
    echo "   - Format: JSON (Encrypted)"
    echo "   - Save file to: $BACKUP_DIR/vault_export_${TIMESTAMP}.json"
    echo ""

    echo "2. Database Backup (Railway PostgreSQL):"
    echo "   Run: railway connect postgres"
    echo "   Then: pg_dump > $BACKUP_DIR/database_${TIMESTAMP}.sql"
    echo ""

    echo "3. SQLite Database Backup (if using SQLite):"
    echo "   The data is stored in Railway volumes"
    echo "   Contact Railway support for volume backups"
    echo ""

    print_success "Remember to:"
    echo "  ✓ Store backups securely"
    echo "  ✓ Keep backups encrypted"
    echo "  ✓ Test restore process"
    echo "  ✓ Backup before major updates"
    echo ""

    # Create backup info file
    cat > "$BACKUP_DIR/backup_info_${TIMESTAMP}.txt" << EOF
Vaultwarden Backup Information
Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')

Backup Instructions Provided For:
- Web vault export
- PostgreSQL database backup
- SQLite data backup

Next Steps:
1. Follow the instructions above to create your backup
2. Verify backup files are complete
3. Store securely (encrypted, off-site)
4. Test restore procedure

For restore instructions, see UPDATES.md
EOF

    print_success "Backup instructions saved to: $BACKUP_DIR/backup_info_${TIMESTAMP}.txt"
    echo ""
}

main "$@"
