#!/usr/bin/env python3
"""
Vaultwarden URI Cleanup Script
Converts insecure HTTP URIs to HTTPS in vault items.
"""

import requests
import json
import sys
from urllib.parse import urlparse, urlunparse
from typing import List, Dict, Any

# Configuration
VAULTWARDEN_URL = "https://vaultwarden-production-3fc2.up.railway.app"
CLIENT_ID = "REDACTED_BW_CLIENT_ID"
CLIENT_SECRET = "REDACTED_BW_CLIENT_SECRET"

class VaultwardenAPI:
    def __init__(self, base_url: str, client_id: str, client_secret: str):
        self.base_url = base_url.rstrip('/')
        self.client_id = client_id
        self.client_secret = client_secret
        self.access_token = None
        self.session = requests.Session()

    def authenticate(self) -> bool:
        """Authenticate using OAuth 2.0 client credentials flow."""
        # Try the standard OAuth endpoint first
        auth_url = f"{self.base_url}/identity/connect/token"

        data = {
            'grant_type': 'client_credentials',
            'scope': 'api',
            'client_id': self.client_id,
            'client_secret': self.client_secret
        }

        headers = {
            'Content-Type': 'application/x-www-form-urlencoded'
        }

        try:
            print(f"🔑 Attempting authentication at: {auth_url}")
            response = self.session.post(auth_url, data=data, headers=headers)
            response.raise_for_status()

            token_data = response.json()
            self.access_token = token_data.get('access_token')

            if self.access_token:
                self.session.headers.update({
                    'Authorization': f'Bearer {self.access_token}'
                })
                print("✅ Authentication successful")
                return True
            else:
                print("❌ No access token received")
                return False

        except requests.exceptions.RequestException as e:
            print(f"❌ Authentication failed: {e}")
            if hasattr(e, 'response') and e.response is not None:
                print(f"Response status: {e.response.status_code}")
                print(f"Response: {e.response.text}")
            return False

    def get_ciphers(self) -> List[Dict[str, Any]]:
        """Retrieve all cipher items from the vault."""
        ciphers_url = f"{self.base_url}/api/ciphers"

        try:
            response = self.session.get(ciphers_url)
            response.raise_for_status()

            data = response.json()
            ciphers = data.get('data', [])
            print(f"📦 Retrieved {len(ciphers)} vault items")
            return ciphers

        except requests.exceptions.RequestException as e:
            print(f"❌ Failed to retrieve ciphers: {e}")
            return []

    def update_cipher(self, cipher_id: str, cipher_data: Dict[str, Any]) -> bool:
        """Update a cipher item."""
        update_url = f"{self.base_url}/api/ciphers/{cipher_id}"

        try:
            response = self.session.put(update_url, json=cipher_data)
            response.raise_for_status()
            return True

        except requests.exceptions.RequestException as e:
            print(f"❌ Failed to update cipher {cipher_id}: {e}")
            return False

def convert_http_to_https(uri: str) -> tuple[str, bool]:
    """
    Convert HTTP URI to HTTPS.
    Returns (new_uri, was_changed)
    """
    if not uri:
        return uri, False

    parsed = urlparse(uri)

    if parsed.scheme == 'http':
        # Convert to HTTPS
        new_parsed = parsed._replace(scheme='https')
        new_uri = urlunparse(new_parsed)
        return new_uri, True

    return uri, False

def find_http_uris(ciphers: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Find all ciphers with HTTP URIs."""
    http_ciphers = []

    for cipher in ciphers:
        # Check login URIs
        login_data = cipher.get('login', {})
        uris = login_data.get('uris', [])

        has_http = False
        for uri_obj in uris:
            uri = uri_obj.get('uri', '')
            if uri.startswith('http://'):
                has_http = True
                break

        if has_http:
            http_ciphers.append(cipher)

    return http_ciphers

def display_cipher_info(cipher: Dict[str, Any], index: int):
    """Display information about a cipher."""
    name = cipher.get('name', 'Unnamed')
    login_data = cipher.get('login', {})
    uris = login_data.get('uris', [])

    print(f"\n{index}. {name}")
    print(f"   ID: {cipher.get('id')}")

    for uri_obj in uris:
        uri = uri_obj.get('uri', '')
        if uri.startswith('http://'):
            new_uri, _ = convert_http_to_https(uri)
            print(f"   🔓 {uri}")
            print(f"   🔒 {new_uri}")

def update_cipher_uris(cipher: Dict[str, Any]) -> Dict[str, Any]:
    """Update all HTTP URIs to HTTPS in a cipher."""
    login_data = cipher.get('login', {})
    uris = login_data.get('uris', [])

    updated = False
    for uri_obj in uris:
        uri = uri_obj.get('uri', '')
        new_uri, changed = convert_http_to_https(uri)

        if changed:
            uri_obj['uri'] = new_uri
            updated = True

    return cipher, updated

def main():
    print("🔐 Vaultwarden HTTP URI Cleanup Script")
    print("=" * 50)

    # Initialize API client
    api = VaultwardenAPI(VAULTWARDEN_URL, CLIENT_ID, CLIENT_SECRET)

    # Authenticate
    if not api.authenticate():
        print("❌ Failed to authenticate. Exiting.")
        sys.exit(1)

    print("\n📥 Fetching vault items...")
    ciphers = api.get_ciphers()

    if not ciphers:
        print("ℹ️  No vault items found or failed to retrieve.")
        sys.exit(0)

    # Find ciphers with HTTP URIs
    http_ciphers = find_http_uris(ciphers)

    if not http_ciphers:
        print("\n✅ No HTTP URIs found. All URIs are already secure!")
        sys.exit(0)

    print(f"\n🔍 Found {len(http_ciphers)} items with HTTP URIs:")
    print("=" * 50)

    # Display all items with HTTP URIs
    for idx, cipher in enumerate(http_ciphers, 1):
        display_cipher_info(cipher, idx)

    # Ask for confirmation
    print("\n" + "=" * 50)
    print(f"📊 Summary: {len(http_ciphers)} items will be updated")

    if len(sys.argv) > 1 and sys.argv[1] == '--dry-run':
        print("\n🔍 DRY RUN MODE - No changes will be made")
        sys.exit(0)

    response = input("\n❓ Proceed with updating these items? (yes/no): ")

    if response.lower() not in ['yes', 'y']:
        print("❌ Update cancelled.")
        sys.exit(0)

    # Update ciphers
    print("\n🔄 Updating vault items...")
    success_count = 0
    fail_count = 0

    for cipher in http_ciphers:
        updated_cipher, was_updated = update_cipher_uris(cipher)

        if was_updated:
            cipher_id = cipher.get('id')
            name = cipher.get('name', 'Unnamed')

            if api.update_cipher(cipher_id, updated_cipher):
                print(f"✅ Updated: {name}")
                success_count += 1
            else:
                print(f"❌ Failed: {name}")
                fail_count += 1

    # Final summary
    print("\n" + "=" * 50)
    print("📊 Update Summary:")
    print(f"   ✅ Successfully updated: {success_count}")
    print(f"   ❌ Failed: {fail_count}")
    print(f"   📈 Total processed: {len(http_ciphers)}")
    print("=" * 50)

    if success_count > 0:
        print("\n✨ Your vault URIs have been secured!")

if __name__ == '__main__':
    main()
