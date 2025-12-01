#!/usr/bin/env python3
"""
Vaultwarden URI Cleanup Script (CLI-based)
Uses Bitwarden CLI to convert insecure HTTP URIs to HTTPS in vault items.

This script installs and uses the official Bitwarden CLI which is compatible
with Vaultwarden. Authentication requires your email and master password.
"""

import subprocess
import json
import sys
import os
from urllib.parse import urlparse, urlunparse
from typing import List, Dict, Any

# Configuration
VAULTWARDEN_URL = "https://vaultwarden-railway-production.up.railway.app"

def run_command(cmd: List[str]) -> tuple[bool, str]:
    """Run a command and return (success, output)."""
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=True
        )
        return True, result.stdout
    except subprocess.CalledProcessError as e:
        return False, e.stderr

def install_bw_cli() -> bool:
    """Install Bitwarden CLI if not already installed."""
    # Check if already installed
    success, _ = run_command(['which', 'bw'])
    if success:
        print("✅ Bitwarden CLI already installed")
        return True

    print("📦 Installing Bitwarden CLI...")

    # Download and install
    commands = [
        ['wget', 'https://vault.bitwarden.com/download/?app=cli&platform=linux', '-O', 'bw.zip'],
        ['unzip', '-o', 'bw.zip'],
        ['chmod', '+x', 'bw'],
        ['sudo', 'mv', 'bw', '/usr/local/bin/']
    ]

    for cmd in commands:
        success, output = run_command(cmd)
        if not success:
            print(f"❌ Failed to run: {' '.join(cmd)}")
            print(output)
            return False

    # Clean up
    if os.path.exists('bw.zip'):
        os.remove('bw.zip')

    print("✅ Bitwarden CLI installed successfully")
    return True

def configure_server() -> bool:
    """Configure bw CLI to use Vaultwarden server."""
    print(f"🔧 Configuring server: {VAULTWARDEN_URL}")

    success, output = run_command(['bw', 'config', 'server', VAULTWARDEN_URL])

    if success:
        print("✅ Server configured")
        return True
    else:
        print(f"❌ Failed to configure server: {output}")
        return False

def login() -> tuple[bool, str]:
    """Login to Vaultwarden and return session token."""
    print("\n🔐 Login to Vaultwarden")
    print("You will be prompted for your email and master password.")

    # Get email
    email = input("Email: ").strip()
    if not email:
        print("❌ Email is required")
        return False, ""

    # Use bw login which will prompt for password
    try:
        result = subprocess.run(
            ['bw', 'login', email, '--raw'],
            capture_output=True,
            text=True
        )

        if result.returncode == 0:
            session_token = result.stdout.strip()
            print("✅ Login successful")
            return True, session_token
        else:
            print(f"❌ Login failed: {result.stderr}")
            return False, ""

    except Exception as e:
        print(f"❌ Login error: {e}")
        return False, ""

def unlock() -> tuple[bool, str]:
    """Unlock vault and return session token."""
    print("\n🔓 Unlocking vault")

    try:
        result = subprocess.run(
            ['bw', 'unlock', '--raw'],
            capture_output=True,
            text=True
        )

        if result.returncode == 0:
            session_token = result.stdout.strip()
            print("✅ Vault unlocked")
            return True, session_token
        else:
            print(f"❌ Unlock failed: {result.stderr}")
            return False, ""

    except Exception as e:
        print(f"❌ Unlock error: {e}")
        return False, ""

def get_session_token() -> str:
    """Get session token by logging in or unlocking."""
    # Try unlock first (if already logged in)
    success, token = unlock()
    if success:
        return token

    # Otherwise, login
    success, token = login()
    if success:
        return token

    return ""

def get_items(session_token: str) -> List[Dict[str, Any]]:
    """Get all vault items."""
    print("\n📥 Fetching vault items...")

    env = os.environ.copy()
    env['BW_SESSION'] = session_token

    success, output = run_command(['bw', 'list', 'items'])

    if success:
        items = json.loads(output)
        print(f"📦 Retrieved {len(items)} vault items")
        return items
    else:
        print(f"❌ Failed to fetch items: {output}")
        return []

def convert_http_to_https(uri: str) -> tuple[str, bool]:
    """Convert HTTP URI to HTTPS. Returns (new_uri, was_changed)."""
    if not uri:
        return uri, False

    parsed = urlparse(uri)

    if parsed.scheme == 'http':
        new_parsed = parsed._replace(scheme='https')
        new_uri = urlunparse(new_parsed)
        return new_uri, True

    return uri, False

def find_http_items(items: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Find all items with HTTP URIs."""
    http_items = []

    for item in items:
        if item.get('type') != 1:  # 1 = login type
            continue

        login = item.get('login', {})
        uris = login.get('uris', [])

        has_http = any(
            uri_obj.get('uri', '').startswith('http://')
            for uri_obj in uris
        )

        if has_http:
            http_items.append(item)

    return http_items

def display_item_info(item: Dict[str, Any], index: int):
    """Display information about an item."""
    name = item.get('name', 'Unnamed')
    login = item.get('login', {})
    uris = login.get('uris', [])

    print(f"\n{index}. {name}")
    print(f"   ID: {item.get('id')}")

    for uri_obj in uris:
        uri = uri_obj.get('uri', '')
        if uri.startswith('http://'):
            new_uri, _ = convert_http_to_https(uri)
            print(f"   🔓 {uri}")
            print(f"   🔒 {new_uri}")

def update_item_uris(item: Dict[str, Any]) -> tuple[Dict[str, Any], bool]:
    """Update all HTTP URIs to HTTPS in an item."""
    login = item.get('login', {})
    uris = login.get('uris', [])

    updated = False
    for uri_obj in uris:
        uri = uri_obj.get('uri', '')
        new_uri, changed = convert_http_to_https(uri)

        if changed:
            uri_obj['uri'] = new_uri
            updated = True

    return item, updated

def update_item(item_id: str, item_data: Dict[str, Any], session_token: str) -> bool:
    """Update an item in the vault."""
    env = os.environ.copy()
    env['BW_SESSION'] = session_token

    # Encode item as base64 to handle special characters
    item_json = json.dumps(item_data)

    try:
        result = subprocess.run(
            ['bw', 'edit', 'item', item_id],
            input=item_json,
            env=env,
            capture_output=True,
            text=True
        )

        return result.returncode == 0

    except Exception as e:
        print(f"❌ Update error: {e}")
        return False

def sync_vault(session_token: str):
    """Sync vault after updates."""
    print("\n🔄 Syncing vault...")

    env = os.environ.copy()
    env['BW_SESSION'] = session_token

    success, _ = run_command(['bw', 'sync'])

    if success:
        print("✅ Vault synced")
    else:
        print("⚠️  Sync may have failed, but updates should still be saved")

def main():
    print("🔐 Vaultwarden HTTP URI Cleanup Script (CLI Edition)")
    print("=" * 50)

    # Install bw CLI
    if not install_bw_cli():
        print("❌ Failed to install Bitwarden CLI")
        sys.exit(1)

    # Configure server
    if not configure_server():
        print("❌ Failed to configure server")
        sys.exit(1)

    # Get session token
    session_token = get_session_token()
    if not session_token:
        print("❌ Failed to authenticate")
        sys.exit(1)

    # Get all items
    items = get_items(session_token)
    if not items:
        print("ℹ️  No items found")
        sys.exit(0)

    # Find items with HTTP URIs
    http_items = find_http_items(items)

    if not http_items:
        print("\n✅ No HTTP URIs found. All URIs are already secure!")
        sys.exit(0)

    print(f"\n🔍 Found {len(http_items)} items with HTTP URIs:")
    print("=" * 50)

    # Display all items
    for idx, item in enumerate(http_items, 1):
        display_item_info(item, idx)

    # Check for dry-run
    print("\n" + "=" * 50)
    print(f"📊 Summary: {len(http_items)} items will be updated")

    if len(sys.argv) > 1 and sys.argv[1] == '--dry-run':
        print("\n🔍 DRY RUN MODE - No changes will be made")
        sys.exit(0)

    response = input("\n❓ Proceed with updating these items? (yes/no): ")

    if response.lower() not in ['yes', 'y']:
        print("❌ Update cancelled.")
        sys.exit(0)

    # Update items
    print("\n🔄 Updating vault items...")
    success_count = 0
    fail_count = 0

    for item in http_items:
        updated_item, was_updated = update_item_uris(item)

        if was_updated:
            item_id = item.get('id')
            name = item.get('name', 'Unnamed')

            if update_item(item_id, updated_item, session_token):
                print(f"✅ Updated: {name}")
                success_count += 1
            else:
                print(f"❌ Failed: {name}")
                fail_count += 1

    # Sync vault
    if success_count > 0:
        sync_vault(session_token)

    # Final summary
    print("\n" + "=" * 50)
    print("📊 Update Summary:")
    print(f"   ✅ Successfully updated: {success_count}")
    print(f"   ❌ Failed: {fail_count}")
    print(f"   📈 Total processed: {len(http_items)}")
    print("=" * 50)

    if success_count > 0:
        print("\n✨ Your vault URIs have been secured!")

    # Lock vault
    run_command(['bw', 'lock'])

if __name__ == '__main__':
    main()
