"""
Flask route handlers for the Vaultwarden Monitor Dashboard.
"""

import logging
from datetime import datetime

from flask import Blueprint, render_template, jsonify, request, send_file
from werkzeug.security import check_password_hash

from config import Config
from utils import get_safe_path
from services import (
    get_backups, get_logs, get_system_status,
    verify_backup, create_backup, restore_backup
)

logger = logging.getLogger(__name__)

# Create blueprint
api = Blueprint('api', __name__)
main = Blueprint('main', __name__)


def check_auth(password):
    """Verify admin password."""
    logger.info(f"check_auth called with password length: {len(password)}")
    logger.info(f"Hash to check against length: {len(Config.ADMIN_PASSWORD_HASH)}")
    result = check_password_hash(Config.ADMIN_PASSWORD_HASH, password)
    logger.info(f"check_password_hash result: {result}")
    return result


# Main routes
@main.route('/')
def index():
    """Main dashboard page."""
    return render_template('index.html')


@main.route('/health')
def health():
    """Health check endpoint."""
    return jsonify({'status': 'healthy', 'timestamp': datetime.now().isoformat()})


# API routes
@api.route('/status')
def api_status():
    """Get system status."""
    try:
        status = get_system_status()
        return jsonify({'success': True, 'data': status})
    except Exception as e:
        logger.error(f"Error getting status: {e}")
        return jsonify({'success': False, 'error': 'Failed to retrieve system status'}), 500


@api.route('/backups')
def api_backups():
    """Get list of backups."""
    try:
        backups = get_backups()
        return jsonify({'success': True, 'data': backups})
    except Exception as e:
        logger.error(f"Error getting backups: {e}")
        return jsonify({'success': False, 'error': 'Failed to retrieve backups'}), 500


@api.route('/backups/create', methods=['POST'])
def api_create_backup():
    """Create a new backup."""
    try:
        data = request.get_json()
        password = data.get('password', '')

        logger.info(f"Backup create attempt - received password length: {len(password)}")
        logger.info(f"Expected hash: {Config.ADMIN_PASSWORD_HASH[:50]}...")

        if not check_auth(password):
            logger.warning(f"Authentication failed for backup creation")
            return jsonify({'success': False, 'error': 'Invalid password'}), 401

        result = create_backup()

        if result['success']:
            return jsonify(result)
        else:
            return jsonify(result), 500

    except Exception as e:
        logger.error(f"Error creating backup: {e}")
        return jsonify({'success': False, 'error': 'Failed to create backup'}), 500


@api.route('/backups/verify', methods=['POST'])
def api_verify_backup():
    """Verify a backup file."""
    try:
        data = request.get_json()
        backup_path = data.get('backup_path', '')

        if not backup_path:
            return jsonify({'success': False, 'error': 'Backup path required'}), 400

        # Use get_safe_path to securely construct and validate the file path
        safe_path = get_safe_path(Config.BACKUP_DIR, backup_path)
        if safe_path is None:
            return jsonify({'success': False, 'error': 'Invalid backup filename'}), 400

        if not safe_path.exists():
            return jsonify({'success': False, 'error': 'Backup file not found'}), 404

        logger.info(f"Verifying backup: {safe_path.name}")
        result = verify_backup(str(safe_path))

        return jsonify(result)

    except Exception as e:
        logger.error(f"Error verifying backup: {e}")
        return jsonify({'success': False, 'error': 'Failed to verify backup'}), 500


@api.route('/backups/restore', methods=['POST'])
def api_restore_backup():
    """Restore from a backup."""
    try:
        data = request.get_json()
        backup_path = data.get('backup_path', '')
        password = data.get('password', '')
        skip_backup = data.get('skip_backup', False)
        force = data.get('force', False)

        if not check_auth(password):
            return jsonify({'success': False, 'error': 'Invalid password'}), 401

        if not backup_path:
            return jsonify({'success': False, 'error': 'Backup path required'}), 400

        # Use get_safe_path to securely construct and validate the file path
        safe_path = get_safe_path(Config.BACKUP_DIR, backup_path)
        if safe_path is None:
            return jsonify({'success': False, 'error': 'Invalid backup filename'}), 400

        if not safe_path.exists():
            return jsonify({'success': False, 'error': 'Backup file not found'}), 404

        result = restore_backup(safe_path, skip_backup=skip_backup, force=force)

        if result['success']:
            return jsonify(result)
        else:
            return jsonify(result), 500

    except Exception as e:
        logger.error(f"Error restoring backup: {e}")
        return jsonify({'success': False, 'error': 'Failed to restore backup'}), 500


@api.route('/logs/restore')
def api_restore_logs():
    """Get restore logs."""
    try:
        logs = get_logs(Config.RESTORE_LOG_DIR, limit=20)
        return jsonify({'success': True, 'data': logs})
    except Exception as e:
        logger.error(f"Error getting restore logs: {e}")
        return jsonify({'success': False, 'error': 'Failed to retrieve restore logs'}), 500


@api.route('/logs/verification')
def api_verification_logs():
    """Get verification logs."""
    try:
        logs = get_logs(Config.VERIFICATION_LOG_DIR, limit=20)
        return jsonify({'success': True, 'data': logs})
    except Exception as e:
        logger.error(f"Error getting verification logs: {e}")
        return jsonify({'success': False, 'error': 'Failed to retrieve verification logs'}), 500


@api.route('/logs/download/<log_type>/<filename>')
def api_download_log(log_type, filename):
    """Download a log file."""
    try:
        # Determine log directory
        if log_type == 'restore':
            log_dir = Config.RESTORE_LOG_DIR
        elif log_type == 'verification':
            log_dir = Config.VERIFICATION_LOG_DIR
        else:
            return jsonify({'success': False, 'error': 'Invalid log type'}), 400

        # Use get_safe_path to securely construct and validate the file path
        # This function sanitizes the filename and ensures it stays within log_dir
        safe_path = get_safe_path(log_dir, filename)
        if safe_path is None:
            return jsonify({'success': False, 'error': 'Invalid filename'}), 400

        # safe_path is now a validated Path object within log_dir
        if not safe_path.exists():
            return jsonify({'success': False, 'error': 'Log file not found'}), 404

        return send_file(safe_path, as_attachment=True)

    except Exception as e:
        logger.error(f"Error downloading log: {e}")
        return jsonify({'success': False, 'error': 'Failed to download log file'}), 500
