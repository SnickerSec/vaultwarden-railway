"""
Utility functions for the Vaultwarden Monitor Dashboard.
"""

import os
import subprocess
import logging
from datetime import datetime
from pathlib import Path

from config import Config

logger = logging.getLogger(__name__)


def sanitize_filename(filename):
    """
    Sanitize a filename by removing path traversal sequences and invalid characters.
    Returns only the basename, preventing directory traversal.
    """
    # Remove any path components, only keep filename
    safe_name = os.path.basename(filename)
    # Remove any remaining path separators
    safe_name = safe_name.replace('/', '').replace('\\', '')
    # Remove null bytes and other dangerous characters
    safe_name = safe_name.replace('\x00', '').replace('..', '')
    return safe_name


def get_safe_path(base_dir, filename):
    """
    Safely construct a path within base_dir from an untrusted filename.
    Returns the safe resolved path if valid, None otherwise.

    This function is a security barrier that:
    1. Extracts only the basename from the input (strips directory components)
    2. Constructs the path within base_dir
    3. Validates the resolved path stays within base_dir

    Args:
        base_dir: The allowed base directory (trusted)
        filename: User-provided filename (untrusted)

    Returns:
        Path object if safe, None otherwise
    """
    try:
        # Reject empty or invalid input
        if not filename or not isinstance(filename, str):
            return None

        # Remove null bytes
        filename = filename.replace('\x00', '')

        # Extract only the basename - this is the key security step
        # os.path.basename strips all directory components, preventing traversal
        safe_name = os.path.basename(filename)

        # Reject if basename is empty or different from input (had path components)
        if not safe_name or safe_name != filename:
            return None

        # Additional safety: reject names with suspicious patterns
        if '..' in safe_name or safe_name.startswith('.'):
            return None

        # Construct the full path within the base directory
        base = Path(base_dir).resolve()
        # Join using the trusted base and sanitized filename
        full_path = base / safe_name

        # Final validation: ensure resolved path is within base
        resolved = full_path.resolve()
        if not resolved.is_relative_to(base):
            return None

        return resolved
    except (ValueError, OSError, RuntimeError):
        return None


def is_safe_path(base_dir, user_path):
    """
    Validate that a user-provided path is within the allowed base directory.
    Prevents path traversal attacks.

    DEPRECATED: Use get_safe_path() instead for new code.
    This function is kept for backwards compatibility.
    """
    try:
        if not user_path or not isinstance(user_path, (str, Path)):
            return False

        base = Path(base_dir).resolve()

        if isinstance(user_path, Path):
            target = user_path.resolve()
        else:
            # For string paths, use get_safe_path logic
            safe_name = os.path.basename(str(user_path).replace('\x00', ''))
            if not safe_name:
                return False
            target = (base / safe_name).resolve()

        return target.is_relative_to(base)
    except (ValueError, OSError, RuntimeError):
        return False


def run_command(cmd, timeout=None):
    """
    Execute shell command and return output.

    Note: cmd should be a list of arguments, not a shell string.
    This prevents command injection vulnerabilities.
    Only whitelisted commands are allowed.
    """
    if timeout is None:
        timeout = Config.DEFAULT_COMMAND_TIMEOUT

    try:
        # Validate command is in whitelist
        if not isinstance(cmd, list) or len(cmd) == 0:
            raise ValueError("Command must be a non-empty list")

        if cmd[0] not in Config.ALLOWED_COMMANDS:
            logger.error(f"Attempted to run disallowed command: {cmd[0]}")
            raise ValueError(f"Command not allowed: {cmd[0]}")

        # Additional validation: ensure no command arguments contain shell metacharacters
        for arg in cmd:
            if not isinstance(arg, str):
                raise ValueError("All command arguments must be strings")
            # Check for dangerous characters that could be exploited
            if any(char in arg for char in ['|', '&', ';', '\n', '`', '$', '(', ')']):
                raise ValueError("Invalid characters in command argument")

        # Safe: shell=False prevents command injection, and we validate all arguments above
        # lgtm[py/command-line-injection]
        result = subprocess.run(
            cmd,
            shell=False,  # Disable shell to prevent command injection
            capture_output=True,
            text=True,
            timeout=timeout,
            cwd=Config.SCRIPTS_DIR
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
            'stderr': 'Command execution timed out',
            'returncode': -1
        }
    except ValueError as e:
        logger.error(f"Command validation failed: {e}")
        return {
            'success': False,
            'stdout': '',
            'stderr': 'Invalid command',
            'returncode': -1
        }
    except Exception as e:
        logger.error(f"Command execution failed: {e}")
        return {
            'success': False,
            'stdout': '',
            'stderr': 'Command execution failed',
            'returncode': -1
        }


def format_bytes(bytes_size):
    """Format bytes to human readable size."""
    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if bytes_size < 1024.0:
            return f"{bytes_size:.2f} {unit}"
        bytes_size /= 1024.0
    return f"{bytes_size:.2f} PB"


def time_ago(dt):
    """Calculate human-readable time ago."""
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


def get_file_info(filepath):
    """Get detailed file information."""
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
