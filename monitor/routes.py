"""
Flask route handlers for the Vaultwarden Monitor Dashboard.
"""

import logging
from datetime import datetime

from flask import Blueprint, render_template, jsonify, request, send_file
from werkzeug.security import check_password_hash

from config import Config
from utils import sanitize_filename, is_safe_path
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
    return check_password_hash(Config.ADMIN_PASSWORD_HASH, password)


# Main routes
@main.route('/')
def index():
    """Main dashboard page."""
    return render_template('index.html')


@main.route('/health')
def health():
    """Health check endpoint."""
    return jsonify({'status': 'healthy', 'timestamp': datetime.now().isoformat()})


@main.route('/debug/config')
def debug_config():
    """Debug endpoint to check configuration (remove in production)."""
    import os
    return jsonify({
        'has_password_hash': bool(os.environ.get('MONITOR_PASSWORD_HASH')),
        'password_hash_length': len(os.environ.get('MONITOR_PASSWORD_HASH', '')),
        'has_secret_key': bool(os.environ.get('MONITOR_SECRET_KEY')),
        'port': Config.PORT,
        'debug': Config.DEBUG
    })


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

        if not check_auth(password):
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

        # Sanitize filename first - only use basename to prevent directory traversal
        safe_filename = sanitize_filename(backup_path)
        if not safe_filename or safe_filename != backup_path:
            return jsonify({'success': False, 'error': 'Invalid backup filename'}), 400

        # Create safe path within backup directory
        backup_file = Config.BACKUP_DIR / safe_filename

        # Double-check path is safe
        if not is_safe_path(Config.BACKUP_DIR, backup_file):
            return jsonify({'success': False, 'error': 'Invalid backup path'}), 400

        if not backup_file.exists():
            return jsonify({'success': False, 'error': 'Backup file not found'}), 404

        logger.info(f"Verifying backup: {backup_file.name}")
        result = verify_backup(str(backup_file))

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

        # Sanitize filename first - only use basename to prevent directory traversal
        safe_filename = sanitize_filename(backup_path)
        if not safe_filename or safe_filename != backup_path:
            return jsonify({'success': False, 'error': 'Invalid backup filename'}), 400

        # Create safe path within backup directory
        backup_file = Config.BACKUP_DIR / safe_filename

        # Double-check path is safe
        if not is_safe_path(Config.BACKUP_DIR, backup_file):
            return jsonify({'success': False, 'error': 'Invalid backup path'}), 400

        if not backup_file.exists():
            return jsonify({'success': False, 'error': 'Backup file not found'}), 404

        result = restore_backup(backup_file, skip_backup=skip_backup, force=force)

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

        # Sanitize filename - only use basename to prevent directory traversal
        safe_filename = sanitize_filename(filename)
        if not safe_filename or safe_filename != filename:
            return jsonify({'success': False, 'error': 'Invalid filename'}), 400

        # Create safe path within log directory
        log_file = log_dir / safe_filename

        # Double-check path is safe
        if not is_safe_path(log_dir, log_file):
            return jsonify({'success': False, 'error': 'Invalid file path'}), 400

        if not log_file.exists():
            return jsonify({'success': False, 'error': 'Log file not found'}), 404

        return send_file(log_file, as_attachment=True)

    except Exception as e:
        logger.error(f"Error downloading log: {e}")
        return jsonify({'success': False, 'error': 'Failed to download log file'}), 500
