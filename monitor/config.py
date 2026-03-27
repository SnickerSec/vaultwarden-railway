"""
Configuration management for the Vaultwarden Monitor Dashboard.
"""

import os
from pathlib import Path


class Config:
    """Application configuration."""

    # Flask settings
    SECRET_KEY = os.environ.get('MONITOR_SECRET_KEY', '')
    JSON_SORT_KEYS = False

    # Directory paths
    BACKUP_DIR = Path(os.environ.get('BACKUP_DIR', '../backups'))
    RESTORE_LOG_DIR = Path(os.environ.get('RESTORE_LOG_DIR', '../restore-logs'))
    VERIFICATION_LOG_DIR = Path(os.environ.get('VERIFICATION_LOG_DIR', '../verification-logs'))
    SCRIPTS_DIR = Path(os.environ.get('SCRIPTS_DIR', '../scripts'))

    # Authentication - MUST be set via environment variable
    ADMIN_PASSWORD_HASH = os.environ.get('MONITOR_PASSWORD_HASH')

    # Server settings
    PORT = int(os.environ.get('MONITOR_PORT', 5000))
    DEBUG = False  # Never enable debug mode — Werkzeug debugger allows RCE
    HOST = '0.0.0.0'

    # Vaultwarden settings
    VAULTWARDEN_URL = os.environ.get('VAULTWARDEN_URL', '')

    # Command whitelist for security
    ALLOWED_COMMANDS = [
        './backup-vault.sh',
        './restore-vault.sh',
        './verify-backup.sh',
        'which'
    ]

    # Notifications (optional — Discord, Slack, or any webhook that accepts JSON POST)
    NOTIFICATION_WEBHOOK_URL = os.environ.get('NOTIFICATION_WEBHOOK_URL', '')

    # Timeouts
    DEFAULT_COMMAND_TIMEOUT = 300  # 5 minutes
    SHORT_COMMAND_TIMEOUT = 5
    LONG_COMMAND_TIMEOUT = 600  # 10 minutes


def ensure_directories():
    """Ensure all required directories exist."""
    Config.BACKUP_DIR.mkdir(exist_ok=True, parents=True)
    Config.RESTORE_LOG_DIR.mkdir(exist_ok=True, parents=True)
    Config.VERIFICATION_LOG_DIR.mkdir(exist_ok=True, parents=True)
