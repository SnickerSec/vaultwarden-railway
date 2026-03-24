"""
Tests for Flask routes.
"""

import os
import sys

import pytest
from werkzeug.security import generate_password_hash

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app import create_app

TEST_PASSWORD = 'test-password-123'


@pytest.fixture
def app(monkeypatch):
    """Create application for testing."""
    password_hash = generate_password_hash(TEST_PASSWORD)
    monkeypatch.setenv('MONITOR_PASSWORD_HASH', password_hash)
    # Patch Config directly since class attributes are evaluated at import time
    from config import Config
    monkeypatch.setattr(Config, 'ADMIN_PASSWORD_HASH', password_hash)
    app = create_app()
    app.config['TESTING'] = True
    app.config['WTF_CSRF_ENABLED'] = False
    return app


@pytest.fixture
def client(app):
    """Create test client."""
    return app.test_client()


def login(client, password=TEST_PASSWORD):
    """Helper to log in and get an authenticated session."""
    return client.post('/api/login',
                       json={'password': password},
                       content_type='application/json')


@pytest.fixture
def auth_client(client):
    """Create an authenticated test client."""
    login(client)
    return client


class TestHealthEndpoint:
    """Tests for health check endpoint."""

    def test_health_returns_200(self, client):
        """Test that health endpoint returns 200."""
        response = client.get('/health')
        assert response.status_code == 200

    def test_health_returns_json(self, client):
        """Test that health endpoint returns JSON."""
        response = client.get('/health')
        data = response.get_json()
        assert data['status'] == 'healthy'
        assert 'timestamp' in data


class TestIndexRoute:
    """Tests for main index route."""

    def test_index_returns_200(self, client):
        """Test that index returns 200."""
        response = client.get('/')
        assert response.status_code == 200


class TestLogin:
    """Tests for login endpoint."""

    def test_login_with_correct_password(self, client):
        """Test login with correct password."""
        response = login(client)
        assert response.status_code == 200
        data = response.get_json()
        assert data['success'] is True

    def test_login_with_wrong_password(self, client):
        """Test login with wrong password."""
        response = login(client, 'wrong-password')
        assert response.status_code == 401
        data = response.get_json()
        assert data['success'] is False

    def test_login_with_empty_body(self, client):
        """Test login with empty body."""
        response = client.post('/api/login',
                               data='not json',
                               content_type='text/plain')
        assert response.status_code in [400, 500]


class TestApiStatus:
    """Tests for API status endpoint."""

    def test_status_requires_auth(self, client):
        """Test that status endpoint requires authentication."""
        response = client.get('/api/status')
        assert response.status_code == 401

    def test_status_returns_json(self, auth_client):
        """Test that status endpoint returns JSON when authenticated."""
        response = auth_client.get('/api/status')
        assert response.status_code == 200
        data = response.get_json()
        assert 'success' in data


class TestApiBackups:
    """Tests for backups API endpoint."""

    def test_backups_requires_auth(self, client):
        """Test that backups endpoint requires authentication."""
        response = client.get('/api/backups')
        assert response.status_code == 401

    def test_backups_returns_json(self, auth_client):
        """Test that backups endpoint returns JSON when authenticated."""
        response = auth_client.get('/api/backups')
        assert response.status_code == 200
        data = response.get_json()
        assert 'success' in data


class TestBackupVerify:
    """Tests for backup verify endpoint."""

    def test_verify_requires_auth(self, client):
        """Test that verify requires authentication."""
        response = client.post('/api/backups/verify',
                               json={'backup_path': 'test.gz'},
                               content_type='application/json')
        assert response.status_code == 401

    def test_verify_requires_backup_path(self, auth_client):
        """Test that verify requires backup_path."""
        response = auth_client.post('/api/backups/verify',
                                    json={})
        assert response.status_code == 400
        data = response.get_json()
        assert data['success'] is False

    def test_verify_rejects_path_traversal(self, auth_client):
        """Test that verify rejects path traversal attempts."""
        response = auth_client.post('/api/backups/verify',
                                    json={'backup_path': '../../../etc/passwd'},
                                    content_type='application/json')
        assert response.status_code == 400
        data = response.get_json()
        assert data['success'] is False


class TestBackupRestore:
    """Tests for backup restore endpoint."""

    def test_restore_requires_auth(self, client):
        """Test that restore requires authentication."""
        response = client.post('/api/backups/restore',
                               json={'backup_path': 'test.tar.gz'},
                               content_type='application/json')
        assert response.status_code == 401

    def test_restore_requires_backup_path(self, auth_client):
        """Test that restore requires backup_path."""
        response = auth_client.post('/api/backups/restore',
                                    json={},
                                    content_type='application/json')
        assert response.status_code == 400


class TestLogEndpoints:
    """Tests for log endpoints."""

    def test_restore_logs_requires_auth(self, client):
        """Test that restore logs require authentication."""
        response = client.get('/api/logs/restore')
        assert response.status_code == 401

    def test_verification_logs_requires_auth(self, client):
        """Test that verification logs require authentication."""
        response = client.get('/api/logs/verification')
        assert response.status_code == 401

    def test_download_requires_auth(self, client):
        """Test that log download requires authentication."""
        response = client.get('/api/logs/download/restore/test.log')
        assert response.status_code == 401

    def test_download_rejects_invalid_log_type(self, auth_client):
        """Test that download rejects invalid log type."""
        response = auth_client.get('/api/logs/download/invalid/test.log')
        assert response.status_code == 400
        data = response.get_json()
        assert data['success'] is False
        assert 'Invalid log type' in data['error']

    def test_download_rejects_path_traversal(self, auth_client):
        """Test that download rejects path traversal."""
        response = auth_client.get('/api/logs/download/restore/..%2F..%2Fetc%2Fpasswd')
        assert response.status_code in [400, 404]

    def test_download_handles_nonexistent_file(self, auth_client):
        """Test that download handles nonexistent files."""
        response = auth_client.get('/api/logs/download/restore/nonexistent.log')
        assert response.status_code in [400, 404]


class TestDebugEndpointRemoved:
    """Test that debug endpoint has been removed."""

    def test_debug_config_not_accessible(self, client):
        """Test that /debug/config endpoint no longer exists."""
        response = client.get('/debug/config')
        assert response.status_code == 404
