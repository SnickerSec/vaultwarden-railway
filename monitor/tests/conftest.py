"""
Pytest configuration and fixtures for monitor tests.
"""

import os
import sys
import tempfile
from pathlib import Path

import pytest

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


@pytest.fixture(autouse=True)
def setup_test_env(tmp_path, monkeypatch):
    """Set up test environment variables."""
    # Create temp directories for testing
    backup_dir = tmp_path / "backups"
    backup_dir.mkdir()

    restore_log_dir = tmp_path / "restore-logs"
    restore_log_dir.mkdir()

    verification_log_dir = tmp_path / "verification-logs"
    verification_log_dir.mkdir()

    scripts_dir = tmp_path / "scripts"
    scripts_dir.mkdir()

    # Set environment variables
    monkeypatch.setenv('BACKUP_DIR', str(backup_dir))
    monkeypatch.setenv('RESTORE_LOG_DIR', str(restore_log_dir))
    monkeypatch.setenv('VERIFICATION_LOG_DIR', str(verification_log_dir))
    monkeypatch.setenv('SCRIPTS_DIR', str(scripts_dir))
    from werkzeug.security import generate_password_hash
    monkeypatch.setenv('MONITOR_SECRET_KEY', 'test-secret-key')
    monkeypatch.setenv('MONITOR_PASSWORD_HASH', generate_password_hash('test-password-123'))
