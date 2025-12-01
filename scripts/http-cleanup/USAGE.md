# Vaultwarden HTTP to HTTPS URI Cleanup

This script automatically converts all insecure HTTP URIs to HTTPS in your Vaultwarden vault.

## Quick Start

### Option 1: Interactive Mode (Enter password when prompted)

```bash
# Dry-run to see what will change
./scripts/cleanup-http-uris-apikey.sh --dry-run

# Actual update
./scripts/cleanup-http-uris-apikey.sh
```

You'll be prompted to enter your master password.

### Option 2: Automated Mode (Use environment variable)

```bash
# Set your master password as an environment variable
export BW_PASSWORD='your-master-password-here'

# Dry-run
./scripts/cleanup-http-uris-apikey.sh --dry-run

# Actual update
./scripts/cleanup-http-uris-apikey.sh
```

## What the Script Does

1. ✅ Uses your API key for authentication (already configured)
2. 🔓 Unlocks your vault with master password
3. 📥 Fetches all vault items
4. 🔍 Finds items with HTTP URIs
5. 🔄 Converts `http://` to `https://`
6. 💾 Saves changes and syncs vault
7. 🔒 Locks vault when complete

## Dry-Run Mode

**Always run with `--dry-run` first!** This shows you what will change without making any modifications:

```bash
export BW_PASSWORD='your-password'
./scripts/cleanup-http-uris-apikey.sh --dry-run
```

Output example:
```
Found 170 items with HTTP URIs:
======================================
Showing first 10 items (total: 170):

Example Site
  ID: abc123-def456
  HTTP URIs: http://example.com

Another Site
  ID: xyz789-uvw012
  HTTP URIs: http://test.com/login, http://test.com/api

... and 160 more items
======================================
📊 Summary: 170 items with HTTP URIs found

🔍 DRY RUN MODE - No changes will be made

Example conversions:
  🔓 http://example.com
  🔒 https://example.com
  🔓 http://test.com/login
  🔒 https://test.com/login
```

## Actual Update

Once you've reviewed the dry-run output:

```bash
export BW_PASSWORD='your-password'
./scripts/cleanup-http-uris-apikey.sh
```

The script will:
- Show you all items to be updated
- Ask for confirmation: `Proceed with updating these 170 items? (yes/no):`
- Update each item and show progress
- Provide a final summary

## Authentication Details

### API Key (Already Configured)
- **Client ID:** `REDACTED_BW_CLIENT_ID`
- **Client Secret:** `REDACTED_BW_CLIENT_SECRET`

The API key authenticates you as a user, but your **master password** is still required to decrypt vault data. This is a security feature.

### Master Password Options

**Option 1: Environment Variable (Recommended for automation)**
```bash
export BW_PASSWORD='your-master-password'
./scripts/cleanup-http-uris-apikey.sh
```

**Option 2: Interactive Prompt**
```bash
./scripts/cleanup-http-uris-apikey.sh
# You'll be prompted: ? Master password: [input is hidden]
```

**Option 3: Password File**
```bash
echo 'your-master-password' > ~/.bw-password
chmod 600 ~/.bw-password
bw unlock --passwordfile ~/.bw-password
```

## Safety Features

- ✅ Dry-run mode to preview changes
- ✅ Confirmation prompt before updates
- ✅ Progress tracking for each item
- ✅ Success/failure summary
- ✅ Automatic vault sync
- ✅ Automatic vault lock on completion

## Troubleshooting

### "Failed to unlock vault"
```bash
# Verify your password is correct
export BW_PASSWORD='your-password'
bw unlock --passwordenv BW_PASSWORD
```

### "API key authentication failed"
The API credentials are hardcoded in the script. If this fails, check that your Vaultwarden instance is accessible.

### "Some items failed to update"
Re-run the script - it will only process items that still have HTTP URIs, skipping already-updated items.

## Security Notes

⚠️ **Keep your credentials secure:**
- Don't commit `BW_PASSWORD` to git
- Clear the environment variable after use: `unset BW_PASSWORD`
- Use a password manager (like Vaultwarden!) to store credentials

## Example Full Workflow

```bash
# 1. Set password (one-time)
export BW_PASSWORD='my-secure-master-password'

# 2. Run dry-run to see what will change
./scripts/cleanup-http-uris-apikey.sh --dry-run

# 3. Review the output, then run actual update
./scripts/cleanup-http-uris-apikey.sh

# 4. When prompted, type 'yes' to confirm

# 5. Wait for completion (170 items may take a few minutes)

# 6. Clear password from environment
unset BW_PASSWORD
```

## Expected Results

For your vault with 170 HTTP URIs, you should see output like:

```
📊 Update Summary:
   ✅ Successfully updated: 170
   ❌ Failed: 0
   📈 Total processed: 170

✨ Your vault URIs have been secured!

🔒 Vault locked
```

All your vault items will now use HTTPS instead of HTTP for their URIs!
