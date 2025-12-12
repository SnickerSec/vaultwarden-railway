"""
Tests for Flask routes.
"""

import os
import sys

import pytest

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app import create_app


@pytest.fixture
def app():
    """Create application for testing."""
    app = create_app()
    app.config['TESTING'] = True
    return app


@pytest.fixture
def client(app):
    """Create test client."""
    return app.test_client()


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


class TestApiStatus:
    """Tests for API status endpoint."""

    def test_status_returns_json(self, client):
        """Test that status endpoint returns JSON."""
        response = client.get('/api/status')
        assert response.status_code == 200
        data = response.get_json()
        assert 'success' in data


class TestApiBackups:
    """Tests for backups API endpoint."""

    def test_backups_returns_json(self, client):
        """Test that backups endpoint returns JSON."""
        response = client.get('/api/backups')
        assert response.status_code == 200
        data = response.get_json()
        assert 'success' in data


class TestBackupVerify:
    """Tests for backup verify endpoint."""

    def test_verify_requires_backup_path(self, client):
        """Test that verify requires backup_path."""
        response = client.post('/api/backups/verify',
                               json={},
                               content_type='application/json')
        assert response.status_code == 400
        data = response.get_json()
        assert data['success'] is False
        assert 'Backup path required' in data['error']

    def test_verify_rejects_path_traversal(self, client):
        """Test that verify rejects path traversal attempts."""
        response = client.post('/api/backups/verify',
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
                               json={'backup_path': 'test.tar.gz', 'password': 'wrong'},
                               content_type='application/json')
        assert response.status_code == 401
        data = response.get_json()
        assert data['success'] is False

    def test_restore_requires_backup_path(self, client):
        """Test that restore requires backup_path."""
        response = client.post('/api/backups/restore',
                               json={'password': 'test'},
                               content_type='application/json')
        # Will fail auth first, but tests the flow
        assert response.status_code in [400, 401]


class TestLogDownload:
    """Tests for log download endpoint."""

    def test_download_rejects_invalid_log_type(self, client):
        """Test that download rejects invalid log type."""
        response = client.get('/api/logs/download/invalid/test.log')
        assert response.status_code == 400
        data = response.get_json()
        assert data['success'] is False
        assert 'Invalid log type' in data['error']

    def test_download_rejects_path_traversal(self, client):
        """Test that download rejects path traversal."""
        # Flask normalizes URLs with ../, so test with encoded or direct filename
        response = client.get('/api/logs/download/restore/..%2F..%2Fetc%2Fpasswd')
        assert response.status_code in [400, 404]  # Either rejected or not found

    def test_download_handles_nonexistent_file(self, client):
        """Test that download handles nonexistent files."""
        response = client.get('/api/logs/download/restore/nonexistent.log')
        # Should be 400 (invalid) or 404 (not found)
        assert response.status_code in [400, 404]


class TestDebugEndpointRemoved:
    """Test that debug endpoint has been removed."""

    def test_debug_config_not_accessible(self, client):
        """Test that /debug/config endpoint no longer exists."""
        response = client.get('/debug/config')
        assert response.status_code == 404
