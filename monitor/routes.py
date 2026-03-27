"""
Flask route handlers for the Vaultwarden Monitor Dashboard.
"""

import logging
from datetime import datetime
from functools import wraps

from flask import Blueprint, render_template, jsonify, request, send_file, session, g
from werkzeug.security import check_password_hash

from extensions import limiter
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
    return check_password_hash(Config.ADMIN_PASSWORD_HASH, password)


def require_auth(f):
    """Decorator to require session authentication on endpoints."""
    @wraps(f)
    def decorated(*args, **kwargs):
        if not session.get('authenticated'):
            return jsonify({'success': False, 'error': 'Authentication required'}), 401
        return f(*args, **kwargs)
    return decorated


# Main routes
@main.route('/')
def index():
    """Main dashboard page."""
    return render_template('index.html', csp_nonce=g.csp_nonce)


@main.route('/health')
def health():
    """Health check endpoint."""
    return jsonify({'status': 'healthy', 'timestamp': datetime.now().isoformat()})


# Auth routes
@api.route('/login', methods=['POST'])
@limiter.limit("5 per minute")
def api_login():
    """Authenticate and create session."""
    try:
        data = request.get_json()
        if not data:
            return jsonify({'success': False, 'error': 'Invalid request'}), 400

        password = data.get('password', '')

        if not check_auth(password):
            logger.warning("Authentication failed from %s", request.remote_addr)
            return jsonify({'success': False, 'error': 'Invalid password'}), 401

        # Regenerate session to prevent session fixation
        session.clear()
        session['authenticated'] = True
        session.permanent = True
        logger.info("Successful login from %s", request.remote_addr)
        return jsonify({'success': True})

    except Exception as e:
        logger.error(f"Login error: {e}")
        return jsonify({'success': False, 'error': 'Login failed'}), 500


@api.route('/logout', methods=['POST'])
def api_logout():
    """Clear session."""
    session.clear()
    return jsonify({'success': True})


# API routes
@api.route('/status')
@require_auth
def api_status():
    """Get system status."""
    try:
        status = get_system_status()
        return jsonify({'success': True, 'data': status})
    except Exception as e:
        logger.error(f"Error getting status: {e}")
        return jsonify({'success': False, 'error': 'Failed to retrieve system status'}), 500


@api.route('/backups')
@require_auth
def api_backups():
    """Get list of backups."""
    try:
        backups = get_backups()
        return jsonify({'success': True, 'data': backups})
    except Exception as e:
        logger.error(f"Error getting backups: {e}")
        return jsonify({'success': False, 'error': 'Failed to retrieve backups'}), 500


@api.route('/backups/create', methods=['POST'])
@require_auth
def api_create_backup():
    """Create a new backup."""
    try:
        result = create_backup()

        if result['success']:
            return jsonify(result)
        else:
            return jsonify(result), 500

    except Exception as e:
        logger.error(f"Error creating backup: {e}")
        return jsonify({'success': False, 'error': 'Failed to create backup'}), 500


@api.route('/backups/verify', methods=['POST'])
@require_auth
def api_verify_backup():
    """Verify a backup file."""
    try:
        data = request.get_json()
        if not data:
            return jsonify({'success': False, 'error': 'Invalid request'}), 400

        backup_path = data.get('backup_path', '')

        if not backup_path:
            return jsonify({'success': False, 'error': 'Backup path required'}), 400

        # Use get_safe_path to securely construct and validate the file path
        safe_path = get_safe_path(Config.BACKUP_DIR, backup_path)
        if safe_path is None:
            return jsonify({'success': False, 'error': 'Invalid backup filename'}), 400

        if not safe_path.exists():
            return jsonify({'success': False, 'error': 'Backup file not found'}), 404

        logger.info("Verifying backup: %s (from %s)", safe_path.name, request.remote_addr)
        result = verify_backup(str(safe_path))

        return jsonify(result)

    except Exception as e:
        logger.error(f"Error verifying backup: {e}")
        return jsonify({'success': False, 'error': 'Failed to verify backup'}), 500


@api.route('/backups/restore', methods=['POST'])
@require_auth
def api_restore_backup():
    """Restore from a backup."""
    try:
        data = request.get_json()
        if not data:
            return jsonify({'success': False, 'error': 'Invalid request'}), 400

        backup_path = data.get('backup_path', '')
        skip_backup = data.get('skip_backup', False) is True
        force = data.get('force', False) is True

        if not backup_path:
            return jsonify({'success': False, 'error': 'Backup path required'}), 400

        # Use get_safe_path to securely construct and validate the file path
        safe_path = get_safe_path(Config.BACKUP_DIR, backup_path)
        if safe_path is None:
            return jsonify({'success': False, 'error': 'Invalid backup filename'}), 400

        if not safe_path.exists():
            return jsonify({'success': False, 'error': 'Backup file not found'}), 404

        logger.info("Restoring backup: %s (from %s)", safe_path.name, request.remote_addr)
        result = restore_backup(safe_path, skip_backup=skip_backup, force=force)

        if result['success']:
            return jsonify(result)
        else:
            return jsonify(result), 500

    except Exception as e:
        logger.error(f"Error restoring backup: {e}")
        return jsonify({'success': False, 'error': 'Failed to restore backup'}), 500


@api.route('/backups/delete', methods=['POST'])
@require_auth
def api_delete_backup():
    """Delete a backup file."""
    try:
        data = request.get_json()
        if not data:
            return jsonify({'success': False, 'error': 'Invalid request'}), 400

        backup_path = data.get('backup_path', '')

        if not backup_path:
            return jsonify({'success': False, 'error': 'Backup path required'}), 400

        safe_path = get_safe_path(Config.BACKUP_DIR, backup_path)
        if safe_path is None:
            return jsonify({'success': False, 'error': 'Invalid backup filename'}), 400

        if not safe_path.exists():
            return jsonify({'success': False, 'error': 'Backup file not found'}), 404

        logger.info("Deleting backup: %s (from %s)", safe_path.name, request.remote_addr)
        safe_path.unlink()
        return jsonify({'success': True, 'message': f'Deleted {safe_path.name}'})

    except Exception as e:
        logger.error(f"Error deleting backup: {e}")
        return jsonify({'success': False, 'error': 'Failed to delete backup'}), 500


@api.route('/logs/restore')
@require_auth
def api_restore_logs():
    """Get restore logs."""
    try:
        logs = get_logs(Config.RESTORE_LOG_DIR, limit=20)
        return jsonify({'success': True, 'data': logs})
    except Exception as e:
        logger.error(f"Error getting restore logs: {e}")
        return jsonify({'success': False, 'error': 'Failed to retrieve restore logs'}), 500


@api.route('/logs/verification')
@require_auth
def api_verification_logs():
    """Get verification logs."""
    try:
        logs = get_logs(Config.VERIFICATION_LOG_DIR, limit=20)
        return jsonify({'success': True, 'data': logs})
    except Exception as e:
        logger.error(f"Error getting verification logs: {e}")
        return jsonify({'success': False, 'error': 'Failed to retrieve verification logs'}), 500


@api.route('/logs/download/<log_type>/<filename>')
@require_auth
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
