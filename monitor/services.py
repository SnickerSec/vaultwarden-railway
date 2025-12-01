"""
Service layer for backup and system operations.
"""

import os
import logging
import requests
from datetime import datetime
from pathlib import Path

from config import Config
from utils import get_file_info, format_bytes, run_command, is_safe_path

logger = logging.getLogger(__name__)


def check_vaultwarden_status():
    """Check if Vaultwarden is online and get version info."""
    if not Config.VAULTWARDEN_URL:
        return {
            'online': False,
            'version': None,
            'error': 'VAULTWARDEN_URL not configured'
        }

    try:
        # Try to access the /alive endpoint
        response = requests.get(
            f"{Config.VAULTWARDEN_URL}/alive",
            timeout=5,
            verify=True
        )

        online = response.status_code == 200

        # Try to get version from /api/version endpoint
        version_info = None
        try:
            version_response = requests.get(
                f"{Config.VAULTWARDEN_URL}/api/version",
                timeout=5,
                verify=True
            )
            if version_response.status_code == 200:
                version_data = version_response.json()
                # The response might be just a string or a dict with version info
                if isinstance(version_data, str):
                    version_info = version_data
                elif isinstance(version_data, dict):
                    version_info = version_data.get('version', version_data.get('server_version', 'Unknown'))
                else:
                    version_info = str(version_data)
        except:
            # If version endpoint fails, fall back to checking headers
            try:
                root_response = requests.get(
                    Config.VAULTWARDEN_URL,
                    timeout=5,
                    verify=True
                )
                server_header = root_response.headers.get('Server', '')
                if 'Rocket' in server_header:
                    version_info = 'Rocket (Vaultwarden)'
            except:
                pass

        return {
            'online': online,
            'version': version_info,
            'error': None
        }
    except requests.exceptions.Timeout:
        return {
            'online': False,
            'version': None,
            'error': 'Connection timeout'
        }
    except requests.exceptions.ConnectionError:
        return {
            'online': False,
            'version': None,
            'error': 'Connection refused'
        }
    except Exception as e:
        logger.error(f"Error checking Vaultwarden status: {e}")
        return {
            'online': False,
            'version': None,
            'error': str(e)
        }


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
        'railway_cli_installed': False,
        'psql_installed': False,
        'scripts_exist': {},
        'vaultwarden': {}
    }

    # Check Vaultwarden status
    status['vaultwarden'] = check_vaultwarden_status()

    # Calculate total backup size
    for filepath in Config.BACKUP_DIR.glob('*.sql*'):
        try:
            status['total_backup_size'] += filepath.stat().st_size
        except:
            pass

    status['total_backup_size_human'] = format_bytes(status['total_backup_size'])

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

    logger.info(f"Backup command completed - success: {result['success']}")
    logger.info(f"Backup stdout: {result.get('stdout', 'N/A')}")
    logger.info(f"Backup stderr: {result.get('stderr', 'N/A')}")
    logger.info(f"Backup return code: {result.get('returncode', 'N/A')}")

    if result['success']:
        logger.info("Backup created successfully")
        return {
            'success': True,
            'message': 'Backup created successfully',
            'output': result['stdout']
        }
    else:
        error_msg = result.get('stderr', 'Unknown error')
        logger.error(f"Backup failed: {error_msg}")
        return {
            'success': False,
            'error': f'Backup creation failed: {error_msg}'
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
