"""
Tests for utility functions.
"""

import os
import tempfile
from datetime import datetime, timedelta
from pathlib import Path
from unittest.mock import patch, MagicMock

import pytest

# Add parent directory to path for imports
import sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from utils import get_safe_path, format_bytes, time_ago, get_file_info, run_command


class TestGetSafePath:
    """Tests for get_safe_path function."""

    def test_valid_filename(self, tmp_path):
        """Test with a valid filename."""
        result = get_safe_path(tmp_path, "test.txt")
        assert result is not None
        assert result.name == "test.txt"
        assert result.parent == tmp_path

    def test_empty_filename(self, tmp_path):
        """Test with empty filename."""
        assert get_safe_path(tmp_path, "") is None
        assert get_safe_path(tmp_path, None) is None

    def test_path_traversal_attempt(self, tmp_path):
        """Test that path traversal is blocked."""
        assert get_safe_path(tmp_path, "../etc/passwd") is None
        assert get_safe_path(tmp_path, "..\\windows\\system32") is None
        assert get_safe_path(tmp_path, "/etc/passwd") is None

    def test_hidden_file_rejected(self, tmp_path):
        """Test that hidden files (starting with .) are handled."""
        # secure_filename converts .hidden to hidden
        result = get_safe_path(tmp_path, ".hidden")
        assert result is None  # Changed because .hidden != hidden after sanitization

    def test_null_byte_injection(self, tmp_path):
        """Test that null byte injection is blocked."""
        assert get_safe_path(tmp_path, "file.txt\x00.exe") is None

    def test_non_string_input(self, tmp_path):
        """Test with non-string input."""
        assert get_safe_path(tmp_path, 123) is None
        assert get_safe_path(tmp_path, ["list"]) is None

    def test_filename_with_spaces_rejected(self, tmp_path):
        """Test filename with spaces is rejected (secure_filename converts spaces to underscores)."""
        # secure_filename("my file.txt") returns "my_file.txt", which != original
        result = get_safe_path(tmp_path, "my file.txt")
        assert result is None

    def test_filename_with_underscores(self, tmp_path):
        """Test filename with underscores is accepted."""
        result = get_safe_path(tmp_path, "my_file.txt")
        assert result is not None
        assert result.name == "my_file.txt"


class TestFormatBytes:
    """Tests for format_bytes function."""

    def test_bytes(self):
        assert format_bytes(500) == "500.00 B"

    def test_kilobytes(self):
        assert format_bytes(1024) == "1.00 KB"
        assert format_bytes(2048) == "2.00 KB"

    def test_megabytes(self):
        assert format_bytes(1024 * 1024) == "1.00 MB"

    def test_gigabytes(self):
        assert format_bytes(1024 * 1024 * 1024) == "1.00 GB"

    def test_terabytes(self):
        assert format_bytes(1024 * 1024 * 1024 * 1024) == "1.00 TB"

    def test_petabytes(self):
        assert format_bytes(1024 * 1024 * 1024 * 1024 * 1024) == "1.00 PB"


class TestTimeAgo:
    """Tests for time_ago function."""

    def test_just_now(self):
        result = time_ago(datetime.now())
        assert result == "just now"

    def test_minutes_ago(self):
        result = time_ago(datetime.now() - timedelta(minutes=5))
        assert "minute" in result

    def test_hours_ago(self):
        result = time_ago(datetime.now() - timedelta(hours=3))
        assert "hour" in result

    def test_days_ago(self):
        result = time_ago(datetime.now() - timedelta(days=5))
        assert "day" in result

    def test_months_ago(self):
        result = time_ago(datetime.now() - timedelta(days=60))
        assert "month" in result

    def test_years_ago(self):
        result = time_ago(datetime.now() - timedelta(days=400))
        assert "year" in result


class TestGetFileInfo:
    """Tests for get_file_info function."""

    def test_valid_file(self, tmp_path):
        """Test with a valid file."""
        test_file = tmp_path / "test.txt"
        test_file.write_text("hello world")

        result = get_file_info(test_file)

        assert result is not None
        assert result['name'] == "test.txt"
        assert result['size'] == 11
        assert 'size_human' in result
        assert 'modified' in result
        assert 'permissions' in result

    def test_nonexistent_file(self, tmp_path):
        """Test with a nonexistent file."""
        fake_file = tmp_path / "nonexistent.txt"
        result = get_file_info(fake_file)
        assert result is None


class TestRunCommand:
    """Tests for run_command function."""

    @patch('utils.Config')
    def test_disallowed_command(self, mock_config):
        """Test that disallowed commands are rejected."""
        mock_config.ALLOWED_COMMANDS = ['./backup-vault.sh']
        mock_config.DEFAULT_COMMAND_TIMEOUT = 30

        result = run_command(['rm', '-rf', '/'])

        assert result['success'] is False
        assert result['stderr'] == 'Invalid command'

    @patch('utils.Config')
    def test_empty_command(self, mock_config):
        """Test that empty commands are rejected."""
        mock_config.DEFAULT_COMMAND_TIMEOUT = 30

        result = run_command([])

        assert result['success'] is False

    @patch('utils.Config')
    def test_shell_metacharacters_rejected(self, mock_config):
        """Test that shell metacharacters in arguments are rejected."""
        mock_config.ALLOWED_COMMANDS = ['echo']
        mock_config.DEFAULT_COMMAND_TIMEOUT = 30

        result = run_command(['echo', 'hello; rm -rf /'])

        assert result['success'] is False
        assert result['stderr'] == 'Invalid command'

    @patch('utils.Config')
    def test_pipe_injection_rejected(self, mock_config):
        """Test that pipe injection is rejected."""
        mock_config.ALLOWED_COMMANDS = ['cat']
        mock_config.DEFAULT_COMMAND_TIMEOUT = 30

        result = run_command(['cat', 'file | rm -rf /'])

        assert result['success'] is False

    @patch('utils.Config')
    def test_non_string_arguments_rejected(self, mock_config):
        """Test that non-string arguments are rejected."""
        mock_config.ALLOWED_COMMANDS = ['echo']
        mock_config.DEFAULT_COMMAND_TIMEOUT = 30

        result = run_command(['echo', 123])

        assert result['success'] is False
