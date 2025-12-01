# Vaultwarden HTTP URI Cleanup Script

This script helps you convert insecure HTTP URIs to HTTPS in your Vaultwarden vault items.

## Background

Vaultwarden doesn't support the public REST API - only the internal client API. The OAuth2 client credentials you have are for specific integrations but don't work with the standard API endpoints.

Instead, this script uses the official **Bitwarden CLI** tool, which is fully compatible with Vaultwarden and uses the client API.

## Prerequisites

- Python 3.6+
- Bitwarden CLI (already installed at `/usr/local/bin/bw`)
- Your Vaultwarden email and master password

## Installation

The script will automatically download and install the Bitwarden CLI if it's not already installed.

## Usage

### Dry Run (Recommended First)

Run a dry run to see what would be changed without making any actual updates:

```bash
cd /home/chuck/vaultwarden-railway
python3 scripts/cleanup-http-uris-v2.py --dry-run
```

This will:
1. Install Bitwarden CLI if needed
2. Prompt for your email and master password
3. Show you all vault items with HTTP URIs
4. Display what the new HTTPS URIs would be
5. Exit without making any changes

### Actual Update

Once you've reviewed the dry run results, run without the `--dry-run` flag:

```bash
python3 scripts/cleanup-http-uris-v2.py
```

This will:
1. Show you all items that will be updated
2. Ask for confirmation (yes/no)
3. Update all HTTP URIs to HTTPS
4. Display a summary of successes and failures
5. Sync your vault

## What It Does

The script:
- ✅ Finds all login items with `http://` URIs
- ✅ Converts them to `https://` URIs
- ✅ Preserves all other data (usernames, passwords, notes, etc.)
- ✅ Shows you exactly what will change before making updates
- ✅ Provides a summary of all changes made

## Example Output

```
🔐 Vaultwarden HTTP URI Cleanup Script (CLI Edition)
==================================================
✅ Bitwarden CLI already installed
🔧 Configuring server: https://vaultwarden-production-3fc2.up.railway.app
✅ Server configured

🔓 Unlocking vault
✅ Vault unlocked

📥 Fetching vault items...
📦 Retrieved 170 vault items

🔍 Found 150 items with HTTP URIs:
==================================================

1. Example Site
   ID: abc123...
   🔓 http://example.com
   🔒 https://example.com

2. Another Site
   ID: def456...
   🔓 http://test.com/login
   🔒 https://test.com/login

...

==================================================
📊 Summary: 150 items will be updated

❓ Proceed with updating these items? (yes/no): yes

🔄 Updating vault items...
✅ Updated: Example Site
✅ Updated: Another Site
...

🔄 Syncing vault...
✅ Vault synced

==================================================
📊 Update Summary:
   ✅ Successfully updated: 150
   ❌ Failed: 0
   📈 Total processed: 150
==================================================

✨ Your vault URIs have been secured!
```

## Security Notes

- Your master password is only used to authenticate with your Vaultwarden instance
- The session token is temporary and automatically locked when the script completes
- All communication is over HTTPS to your Vaultwarden server
- No credentials are stored or logged

## Troubleshooting

### "Login failed"
- Verify your email and master password are correct
- Check that your Vaultwarden instance is accessible at the configured URL
- Ensure you don't have 2FA enabled (CLI doesn't support 2FA prompts in scripts)

### "Failed to install Bitwarden CLI"
- Ensure you have sudo access
- Check internet connectivity for downloading the CLI
- Verify wget and unzip are installed

### "Some items failed to update"
- Check the error messages for specific items
- Try updating those items manually through the web vault
- Re-run the script to catch any failed items

## Sources

- [Vaultwarden OAuth2 Discussion](https://github.com/dani-garcia/vaultwarden/discussions/3039)
- [Vaultwarden REST API Discussion](https://github.com/dani-garcia/vaultwarden/discussions/4241)
- [Bitwarden CLI Documentation](https://bitwarden.com/help/cli/)
