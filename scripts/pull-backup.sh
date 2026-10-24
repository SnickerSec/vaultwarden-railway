#!/bin/bash
#
# Vaultwarden Pull Backup
# Dumps PostgreSQL inside the Railway Postgres container over `railway ssh`
# and stores a GPG-encrypted copy locally. The database stays on Railway's
# private network: no public TCP proxy and no database credentials needed.
#
# Required environment:
#   RAILWAY_PROJECT_ID, RAILWAY_ENVIRONMENT_ID
# Optional environment:
#   RAILWAY_DB_SERVICE      Postgres service name (default: Postgres)
#   BACKUP_DIR              Where backups are written (default: ~/vaultwarden-backups)
#   BACKUP_RETENTION_DAYS   Delete backups older than this (default: 30)
#   BACKUP_PASSPHRASE_FILE  GPG passphrase file (default: ~/.config/vaultwarden-backup/passphrase)
#   BACKUP_ISSUE_REPO       owner/repo to open a GitHub issue in on failure
#

set -euo pipefail
umask 077

: "${RAILWAY_PROJECT_ID:?RAILWAY_PROJECT_ID is required}"
: "${RAILWAY_ENVIRONMENT_ID:?RAILWAY_ENVIRONMENT_ID is required}"
RAILWAY_DB_SERVICE="${RAILWAY_DB_SERVICE:-Postgres}"
BACKUP_DIR="${BACKUP_DIR:-$HOME/vaultwarden-backups}"
BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
BACKUP_PASSPHRASE_FILE="${BACKUP_PASSPHRASE_FILE:-$HOME/.config/vaultwarden-backup/passphrase}"
BACKUP_ISSUE_REPO="${BACKUP_ISSUE_REPO:-}"

log() {
    echo "[$(date -u +'%Y-%m-%d %H:%M:%S UTC')] $1"
}

WORK_DIR=""
cleanup() {
    [[ -n "$WORK_DIR" ]] && rm -rf "$WORK_DIR"
}

on_failure() {
    local line="$1"
    log "ERROR: backup failed at line $line"
    if [[ -n "$BACKUP_ISSUE_REPO" ]] && command -v gh >/dev/null; then
        gh issue create -R "$BACKUP_ISSUE_REPO" \
            --title "⚠️ Database Backup Failed" \
            --label backup --label automated --label failure \
            --body "The scheduled pull backup on \`$(hostname)\` failed at $(date -u '+%Y-%m-%d %H:%M:%S UTC').

Check the logs with: \`journalctl --user -u vaultwarden-backup.service -n 100\`" \
            >/dev/null || log "WARNING: could not open GitHub issue"
    fi
}

trap 'on_failure $LINENO' ERR
trap cleanup EXIT

if [[ ! -s "$BACKUP_PASSPHRASE_FILE" ]]; then
    log "ERROR: passphrase file not found: $BACKUP_PASSPHRASE_FILE"
    false
fi

mkdir -p "$BACKUP_DIR"
WORK_DIR=$(mktemp -d "$BACKUP_DIR/.tmp.XXXXXX")
TIMESTAMP=$(date -u +%Y%m%d_%H%M%S)
DUMP="$WORK_DIR/vaultwarden_db_backup_${TIMESTAMP}.sql.gz"
FINAL="$BACKUP_DIR/vaultwarden_db_backup_${TIMESTAMP}.sql.gz.gpg"

# Connect over the container's local socket: it doesn't depend on the
# PGHOST/PGPASSWORD values baked into the container's environment, which go
# stale after a password rotation until Postgres is redeployed.
# base64 keeps the binary stream intact through the SSH session.
REMOTE_CMD='set -o pipefail; unset PGHOST PGPASSWORD
pg_dump -h /var/run/postgresql -U "${POSTGRES_USER:-postgres}" -d "${PGDATABASE:-railway}" --no-owner --no-acl | gzip -c | base64 -w0'

log "Dumping database from Railway service '$RAILWAY_DB_SERVICE'..."
railway ssh \
    --project "$RAILWAY_PROJECT_ID" \
    --environment "$RAILWAY_ENVIRONMENT_ID" \
    --service "$RAILWAY_DB_SERVICE" \
    -- bash -c "$REMOTE_CMD" 2>"$WORK_DIR/ssh.err" | base64 -d > "$DUMP" || {
    log "ERROR: dump transfer failed:"
    cat "$WORK_DIR/ssh.err" >&2
    false
}

# pg_dump errors don't always propagate through the SSH session's exit code,
# so verify the content itself: valid gzip and pg_dump's completion marker.
if ! gzip -t "$DUMP" 2>/dev/null || ! zcat "$DUMP" | grep -q '^-- PostgreSQL database dump complete'; then
    log "ERROR: dump is incomplete or invalid:"
    cat "$WORK_DIR/ssh.err" >&2
    false
fi
TABLES=$(zcat "$DUMP" | grep -c '^CREATE TABLE' || true)
log "Dump verified ($TABLES tables)"

gpg --batch --yes --symmetric --cipher-algo AES256 \
    --passphrase-file "$BACKUP_PASSPHRASE_FILE" --pinentry-mode loopback \
    -o "$WORK_DIR/out.gpg" "$DUMP"
mv "$WORK_DIR/out.gpg" "$FINAL"
log "Backup saved: $FINAL ($(du -h "$FINAL" | cut -f1))"

find "$BACKUP_DIR" -maxdepth 1 -name 'vaultwarden_db_backup_*.sql.gz.gpg' \
    -mtime +"$BACKUP_RETENTION_DAYS" -print -delete | sed 's/^/Removed old backup: /'
