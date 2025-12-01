#!/bin/bash
# Simple HTTP to HTTPS cleanup script

set -e

VAULTWARDEN_URL="https://vaultwarden-railway-production.up.railway.app"
CLIENT_ID="REDACTED_BW_CLIENT_ID"
CLIENT_SECRET="REDACTED_BW_CLIENT_SECRET"

echo "🔐 Vaultwarden HTTP to HTTPS Cleanup"
echo "===================================="

# Configure server
bw config server "$VAULTWARDEN_URL" 2>/dev/null || true

# Login with API key
export BW_CLIENTID="$CLIENT_ID"
export BW_CLIENTSECRET="$CLIENT_SECRET"
bw login --apikey 2>/dev/null || echo "Already logged in"

# Unlock vault
echo "🔓 Unlocking vault..."
SESSION=$(bw unlock --passwordenv BW_PASSWORD --raw)

if [ -z "$SESSION" ]; then
    echo "❌ Failed to unlock vault"
    exit 1
fi

echo "✅ Vault unlocked"

# Get all items with HTTP URIs
echo "📥 Fetching items with HTTP URIs..."
ITEMS=$(bw list items --session "$SESSION" | jq -c '[.[] | select(.type == 1 and .login.uris != null) | select(.login.uris | any(.uri | startswith("http://")))]')

COUNT=$(echo "$ITEMS" | jq 'length')
echo "Found $COUNT items with HTTP URIs"

if [ "$COUNT" -eq 0 ]; then
    echo "✅ All done!"
    bw lock
    exit 0
fi

# Show summary
if [ "$1" = "--dry-run" ]; then
    echo ""
    echo "📋 Items to update:"
    echo "$ITEMS" | jq -r '.[] | "\(.name)"' | head -20
    if [ "$COUNT" -gt 20 ]; then
        echo "... and $(($COUNT - 20)) more"
    fi
    echo ""
    echo "🔍 DRY RUN - No changes made"
    bw lock
    exit 0
fi

# Update items
echo ""
echo "🔄 Updating $COUNT items..."
SUCCESS=0
FAIL=0

echo "$ITEMS" | jq -c '.[]' | while read -r item; do
    ID=$(echo "$item" | jq -r '.id')
    NAME=$(echo "$item" | jq -r '.name')

    # Update HTTP to HTTPS
    UPDATED=$(echo "$item" | jq '.login.uris |= map(if .uri | startswith("http://") then .uri |= sub("^http://"; "https://") else . end)')

    # Save updated item to temp file
    echo "$UPDATED" > /tmp/bw_item_update.json

    # Update the item
    if bw edit item "$ID" /tmp/bw_item_update.json --session "$SESSION" > /dev/null 2>&1; then
        echo "✅ $NAME"
        ((SUCCESS++)) || true
    else
        echo "❌ $NAME"
        ((FAIL++)) || true
    fi
done

# Sync
echo ""
echo "🔄 Syncing vault..."
bw sync --session "$SESSION" > /dev/null 2>&1

# Lock
bw lock

echo ""
echo "======================================"
echo "📊 Complete!"
echo "Run again to see remaining items"
echo "======================================"
