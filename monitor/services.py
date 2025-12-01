"""
Service layer for backup and system operations.
"""

import os
import logging
from datetime import datetime
from pathlib import Path

from config import Config
from utils import get_file_info, format_bytes, run_command, is_safe_path

logger = logging.getLogger(__name__)


def get_backups():
    """Get list of all backup files."""
    backups = []

    # Get all .sql and .sql.gz files
    for pattern in ['*.sql', '*.sql.gz']:
        for filepath in sorted(
            Config.BACKUP_DIR.glob(pattern),
            key=lambda x: x.stat().st_mtime,
            reverse=True
        ):
            info = get_file_info(filepath)
            if info:
                backups.append(info)

    return backups


def get_logs(log_dir, limit=10):
    """Get recent log files."""
    logs = []

    for filepath in sorted(
        log_dir.glob('*.txt'),
        key=lambda x: x.stat().st_mtime,
        reverse=True
    )[:limit]:
        info = get_file_info(filepath)
        if info:
            # Read first few lines
            try:
                with open(filepath, 'r') as f:
                    preview = ''.join(f.readlines()[:5])
                    info['preview'] = preview
            except:
                info['preview'] = 'Unable to read file'
            logs.append(info)

    return logs


def get_system_status():
    """Get system status information."""
    status = {
        'timestamp': datetime.now().isoformat(),
        'backup_dir_exists': Config.BACKUP_DIR.exists(),
        'backup_count': len(list(Config.BACKUP_DIR.glob('*.sql*'))),
        'total_backup_size': 0,
        'latest_backup': None,
        'oldest_backup': None,
        'railway_cli_installed': False,
        'psql_installed': False,
        'scripts_exist': {}
    }

    # Calculate total backup size
    for filepath in Config.BACKUP_DIR.glob('*.sql*'):
        try:
            status['total_backup_size'] += filepath.stat().st_size
        except:
            pass

    status['total_backup_size_human'] = format_bytes(status['total_backup_size'])

    # Get latest and oldest backups
    backups = get_backups()
    if backups:
        status['latest_backup'] = backups[0]
        status['oldest_backup'] = backups[-1]

    # Check for Railway CLI
    result = run_command(['which', 'railway'], timeout=Config.SHORT_COMMAND_TIMEOUT)
    status['railway_cli_installed'] = result['success']

    # Check for psql
    result = run_command(['which', 'psql'], timeout=Config.SHORT_COMMAND_TIMEOUT)
    status['psql_installed'] = result['success']

    # Check for scripts
    scripts = ['backup-vault.sh', 'restore-vault.sh', 'verify-backup.sh']
    for script in scripts:
        script_path = Config.SCRIPTS_DIR / script
        status['scripts_exist'][script] = (
            script_path.exists() and os.access(script_path, os.X_OK)
        )

    return status


def verify_backup(backup_path):
    """Verify a backup file."""
    script = Config.SCRIPTS_DIR / 'verify-backup.sh'
    if not script.exists():
        return {'success': False, 'error': 'Verification script not found'}

    # Validate path to prevent path traversal
    if not is_safe_path(Config.BACKUP_DIR, backup_path):
        return {'success': False, 'error': 'Invalid backup path'}

    cmd = ['./verify-backup.sh', str(backup_path)]
    result = run_command(cmd, timeout=60)

    return {
        'success': result['success'],
        'output': result['stdout'],
        'error': result['stderr'] if result['success'] else 'Verification failed'
    }


def create_backup():
    """Create a new backup."""
    script = Config.SCRIPTS_DIR / 'backup-vault.sh'
    if not script.exists():
        return {'success': False, 'error': 'Backup script not found'}

    logger.info("Starting manual backup...")
    result = run_command(['./backup-vault.sh'], timeout=Config.DEFAULT_COMMAND_TIMEOUT)

    if result['success']:
        logger.info("Backup created successfully")
        return {
            'success': True,
            'message': 'Backup created successfully',
            'output': result['stdout']
        }
    else:
        logger.error(f"Backup failed: {result['stderr']}")
        return {
            'success': False,
            'error': 'Backup creation failed'
        }


def restore_backup(backup_file, skip_backup=False, force=False):
    """Restore from a backup file."""
    script = Config.SCRIPTS_DIR / 'restore-vault.sh'
    if not script.exists():
        return {'success': False, 'error': 'Restore script not found'}

    # Build restore command with proper arguments
    cmd = ['./restore-vault.sh', str(backup_file)]
    if skip_backup:
        cmd.append('--skip-backup')
    if force:
        cmd.append('--force')

    logger.info(f"Starting restore from: {backup_file}")
    result = run_command(cmd, timeout=Config.LONG_COMMAND_TIMEOUT)

    if result['success']:
        logger.info("Restore completed successfully")
        return {
            'success': True,
            'message': 'Restore completed successfully',
            'output': result['stdout']
        }
    else:
        logger.error(f"Restore failed: {result['stderr']}")
        return {
            'success': False,
            'error': 'Restore operation failed'
        }
