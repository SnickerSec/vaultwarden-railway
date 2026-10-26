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
#   BACKUP_RCLONE_REMOTE    rclone destination for offsite copies, e.g.
#                           gdrive:vaultwarden-backups (default: no offsite copy)
#   BACKUP_REMOTE_RETENTION_DAYS  Delete offsite copies older than this (default: 90)
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
BACKUP_RCLONE_REMOTE="${BACKUP_RCLONE_REMOTE:-}"
BACKUP_REMOTE_RETENTION_DAYS="${BACKUP_REMOTE_RETENTION_DAYS:-90}"

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

# Offsite copy. Copies every local backup, not just today's, so a failed
# upload is caught up on the next run. `copy` never deletes remotely; offsite
# copies are pruned separately with their own (longer) retention, so a wiped
# local directory can't wipe the offsite copies with it.
if [[ -n "$BACKUP_RCLONE_REMOTE" ]]; then
    BACKUP_FILTER=(--include 'vaultwarden_db_backup_*.sql.gz.gpg' --max-depth 1)
    log "Copying backups to $BACKUP_RCLONE_REMOTE..."
    rclone copy "$BACKUP_DIR" "$BACKUP_RCLONE_REMOTE" "${BACKUP_FILTER[@]}"
    rclone check --one-way "$BACKUP_DIR" "$BACKUP_RCLONE_REMOTE" "${BACKUP_FILTER[@]}" 2>&1 | tail -1
    PRUNED=$(rclone delete "$BACKUP_RCLONE_REMOTE" "${BACKUP_FILTER[@]}" \
        --min-age "${BACKUP_REMOTE_RETENTION_DAYS}d" -v 2>&1)
    sed -nE 's/^.*INFO  : (.*): Deleted$/Removed old offsite backup: \1/p' <<< "$PRUNED"
    log "Offsite copy verified: $(rclone lsf "$BACKUP_RCLONE_REMOTE" "${BACKUP_FILTER[@]}" | wc -l) backups in $BACKUP_RCLONE_REMOTE"
fi
