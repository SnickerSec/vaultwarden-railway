#!/usr/bin/env python3
"""
Vaultwarden Backup & Restore Monitoring Dashboard

A web-based dashboard for monitoring, creating, and restoring Vaultwarden backups.
Integrates with existing backup and restore scripts.
"""

import os
import json
import subprocess
import glob
import time
from datetime import datetime, timedelta
from pathlib import Path
from flask import Flask, render_template, jsonify, request, send_file
from werkzeug.security import check_password_hash, generate_password_hash
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = Flask(__name__)
app.config['SECRET_KEY'] = os.environ.get('MONITOR_SECRET_KEY', os.urandom(32).hex())
app.config['JSON_SORT_KEYS'] = False

# Configuration
BACKUP_DIR = Path(os.environ.get('BACKUP_DIR', '../backups'))
RESTORE_LOG_DIR = Path(os.environ.get('RESTORE_LOG_DIR', '../restore-logs'))
VERIFICATION_LOG_DIR = Path(os.environ.get('VERIFICATION_LOG_DIR', '../verification-logs'))
SCRIPTS_DIR = Path(os.environ.get('SCRIPTS_DIR', '../scripts'))
ADMIN_PASSWORD_HASH = os.environ.get('MONITOR_PASSWORD_HASH', generate_password_hash('admin'))

# Ensure directories exist
BACKUP_DIR.mkdir(exist_ok=True, parents=True)
RESTORE_LOG_DIR.mkdir(exist_ok=True, parents=True)
VERIFICATION_LOG_DIR.mkdir(exist_ok=True, parents=True)

def check_auth(password):
    """Verify admin password"""
    return check_password_hash(ADMIN_PASSWORD_HASH, password)

def run_command(cmd, timeout=300):
    """Execute shell command and return output"""
    try:
        result = subprocess.run(
            cmd,
            shell=True,
            capture_output=True,
            text=True,
            timeout=timeout,
            cwd=SCRIPTS_DIR
        )
        return {
            'success': result.returncode == 0,
            'stdout': result.stdout,
            'stderr': result.stderr,
            'returncode': result.returncode
        }
    except subprocess.TimeoutExpired:
        return {
            'success': False,
            'stdout': '',
            'stderr': f'Command timed out after {timeout} seconds',
            'returncode': -1
        }
    except Exception as e:
        return {
            'success': False,
            'stdout': '',
            'stderr': str(e),
            'returncode': -1
        }

def get_file_info(filepath):
    """Get detailed file information"""
    try:
        stat = filepath.stat()
        return {
            'name': filepath.name,
            'path': str(filepath),
            'size': stat.st_size,
            'size_human': format_bytes(stat.st_size),
            'modified': datetime.fromtimestamp(stat.st_mtime).isoformat(),
            'modified_ago': time_ago(datetime.fromtimestamp(stat.st_mtime)),
            'permissions': oct(stat.st_mode)[-3:]
        }
    except Exception as e:
        logger.error(f"Error getting file info for {filepath}: {e}")
        return None

def format_bytes(bytes_size):
    """Format bytes to human readable size"""
    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if bytes_size < 1024.0:
            return f"{bytes_size:.2f} {unit}"
        bytes_size /= 1024.0
    return f"{bytes_size:.2f} PB"

def time_ago(dt):
    """Calculate human-readable time ago"""
    now = datetime.now()
    diff = now - dt

    if diff.days > 365:
        years = diff.days // 365
        return f"{years} year{'s' if years > 1 else ''} ago"
    elif diff.days > 30:
        months = diff.days // 30
        return f"{months} month{'s' if months > 1 else ''} ago"
    elif diff.days > 0:
        return f"{diff.days} day{'s' if diff.days > 1 else ''} ago"
    elif diff.seconds > 3600:
        hours = diff.seconds // 3600
        return f"{hours} hour{'s' if hours > 1 else ''} ago"
    elif diff.seconds > 60:
        minutes = diff.seconds // 60
        return f"{minutes} minute{'s' if minutes > 1 else ''} ago"
    else:
        return "just now"

def get_backups():
    """Get list of all backup files"""
    backups = []

    # Get all .sql and .sql.gz files
    for pattern in ['*.sql', '*.sql.gz']:
        for filepath in sorted(BACKUP_DIR.glob(pattern), key=lambda x: x.stat().st_mtime, reverse=True):
            info = get_file_info(filepath)
            if info:
                backups.append(info)

    return backups

def get_logs(log_dir, limit=10):
    """Get recent log files"""
    logs = []

    for filepath in sorted(log_dir.glob('*.txt'), key=lambda x: x.stat().st_mtime, reverse=True)[:limit]:
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
    """Get system status information"""
    status = {
        'timestamp': datetime.now().isoformat(),
        'backup_dir_exists': BACKUP_DIR.exists(),
        'backup_count': len(list(BACKUP_DIR.glob('*.sql*'))),
        'total_backup_size': 0,
        'latest_backup': None,
        'oldest_backup': None,
        'railway_cli_installed': False,
        'psql_installed': False,
        'scripts_exist': {}
    }

    # Calculate total backup size
    for filepath in BACKUP_DIR.glob('*.sql*'):
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
    result = run_command('which railway', timeout=5)
    status['railway_cli_installed'] = result['success']

    # Check for psql
    result = run_command('which psql', timeout=5)
    status['psql_installed'] = result['success']

    # Check for scripts
    scripts = ['backup-vault.sh', 'restore-vault.sh', 'verify-backup.sh']
    for script in scripts:
        script_path = SCRIPTS_DIR / script
        status['scripts_exist'][script] = script_path.exists() and os.access(script_path, os.X_OK)

    return status

def verify_backup(backup_path):
    """Verify a backup file"""
    script = SCRIPTS_DIR / 'verify-backup.sh'
    if not script.exists():
        return {'success': False, 'error': 'Verification script not found'}

    cmd = f'./verify-backup.sh "{backup_path}"'
    result = run_command(cmd, timeout=60)

    return {
        'success': result['success'],
        'output': result['stdout'],
        'error': result['stderr']
    }

@app.route('/')
def index():
    """Main dashboard page"""
    return render_template('index.html')

@app.route('/api/status')
def api_status():
    """Get system status"""
    try:
        status = get_system_status()
        return jsonify({'success': True, 'data': status})
    except Exception as e:
        logger.error(f"Error getting status: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/backups')
def api_backups():
    """Get list of backups"""
    try:
        backups = get_backups()
        return jsonify({'success': True, 'data': backups})
    except Exception as e:
        logger.error(f"Error getting backups: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/backups/create', methods=['POST'])
def api_create_backup():
    """Create a new backup"""
    try:
        data = request.get_json()
        password = data.get('password', '')

        if not check_auth(password):
            return jsonify({'success': False, 'error': 'Invalid password'}), 401

        script = SCRIPTS_DIR / 'backup-vault.sh'
        if not script.exists():
            return jsonify({'success': False, 'error': 'Backup script not found'}), 500

        logger.info("Starting manual backup...")
        result = run_command('./backup-vault.sh', timeout=300)

        if result['success']:
            logger.info("Backup created successfully")
            return jsonify({
                'success': True,
                'message': 'Backup created successfully',
                'output': result['stdout']
            })
        else:
            logger.error(f"Backup failed: {result['stderr']}")
            return jsonify({
                'success': False,
                'error': 'Backup failed',
                'details': result['stderr']
            }), 500

    except Exception as e:
        logger.error(f"Error creating backup: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/backups/verify', methods=['POST'])
def api_verify_backup():
    """Verify a backup file"""
    try:
        data = request.get_json()
        backup_path = data.get('backup_path', '')

        if not backup_path:
            return jsonify({'success': False, 'error': 'Backup path required'}), 400

        # Security check: ensure path is within backup directory
        backup_file = Path(backup_path)
        if not str(backup_file.resolve()).startswith(str(BACKUP_DIR.resolve())):
            return jsonify({'success': False, 'error': 'Invalid backup path'}), 400

        if not backup_file.exists():
            return jsonify({'success': False, 'error': 'Backup file not found'}), 404

        logger.info(f"Verifying backup: {backup_path}")
        result = verify_backup(backup_path)

        return jsonify(result)

    except Exception as e:
        logger.error(f"Error verifying backup: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/backups/restore', methods=['POST'])
def api_restore_backup():
    """Restore from a backup"""
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

        # Security check: ensure path is within backup directory
        backup_file = Path(backup_path)
        if not str(backup_file.resolve()).startswith(str(BACKUP_DIR.resolve())):
            return jsonify({'success': False, 'error': 'Invalid backup path'}), 400

        if not backup_file.exists():
            return jsonify({'success': False, 'error': 'Backup file not found'}), 404

        script = SCRIPTS_DIR / 'restore-vault.sh'
        if not script.exists():
            return jsonify({'success': False, 'error': 'Restore script not found'}), 500

        # Build restore command
        cmd = f'./restore-vault.sh "{backup_path}"'
        if skip_backup:
            cmd += ' --skip-backup'
        if force:
            cmd += ' --force'

        logger.info(f"Starting restore from: {backup_path}")
        result = run_command(cmd, timeout=600)

        if result['success']:
            logger.info("Restore completed successfully")
            return jsonify({
                'success': True,
                'message': 'Restore completed successfully',
                'output': result['stdout']
            })
        else:
            logger.error(f"Restore failed: {result['stderr']}")
            return jsonify({
                'success': False,
                'error': 'Restore failed',
                'details': result['stderr']
            }), 500

    except Exception as e:
        logger.error(f"Error restoring backup: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/logs/restore')
def api_restore_logs():
    """Get restore logs"""
    try:
        logs = get_logs(RESTORE_LOG_DIR, limit=20)
        return jsonify({'success': True, 'data': logs})
    except Exception as e:
        logger.error(f"Error getting restore logs: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/logs/verification')
def api_verification_logs():
    """Get verification logs"""
    try:
        logs = get_logs(VERIFICATION_LOG_DIR, limit=20)
        return jsonify({'success': True, 'data': logs})
    except Exception as e:
        logger.error(f"Error getting verification logs: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/logs/download/<log_type>/<filename>')
def api_download_log(log_type, filename):
    """Download a log file"""
    try:
        # Determine log directory
        if log_type == 'restore':
            log_dir = RESTORE_LOG_DIR
        elif log_type == 'verification':
            log_dir = VERIFICATION_LOG_DIR
        else:
            return jsonify({'success': False, 'error': 'Invalid log type'}), 400

        # Security check
        log_file = log_dir / filename
        if not str(log_file.resolve()).startswith(str(log_dir.resolve())):
            return jsonify({'success': False, 'error': 'Invalid file path'}), 400

        if not log_file.exists():
            return jsonify({'success': False, 'error': 'Log file not found'}), 404

        return send_file(log_file, as_attachment=True)

    except Exception as e:
        logger.error(f"Error downloading log: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/health')
def health():
    """Health check endpoint"""
    return jsonify({'status': 'healthy', 'timestamp': datetime.now().isoformat()})

if __name__ == '__main__':
    port = int(os.environ.get('MONITOR_PORT', 5000))
    debug = os.environ.get('MONITOR_DEBUG', 'false').lower() == 'true'

    logger.info(f"Starting Vaultwarden Monitor on port {port}")
    logger.info(f"Backup directory: {BACKUP_DIR.resolve()}")
    logger.info(f"Scripts directory: {SCRIPTS_DIR.resolve()}")

    app.run(host='0.0.0.0', port=port, debug=debug)
