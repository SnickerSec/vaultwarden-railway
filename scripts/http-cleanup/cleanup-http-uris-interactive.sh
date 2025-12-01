#!/bin/bash
# Interactive wrapper for HTTP URI cleanup script
# This script handles the Bitwarden CLI authentication and then runs the cleanup

set -e

VAULTWARDEN_URL="https://vaultwarden-railway-production.up.railway.app"

echo "🔐 Vaultwarden HTTP URI Cleanup Script"
echo "======================================"
echo ""

# Configure server
echo "🔧 Configuring Bitwarden CLI..."
bw config server "$VAULTWARDEN_URL"

# Check if already logged in
BW_STATUS=$(bw status | jq -r '.status')

if [ "$BW_STATUS" = "unauthenticated" ]; then
    echo ""
    echo "🔐 Please login to Vaultwarden"
    echo "You will be prompted for your email and master password."
    echo ""

    # Prompt for email
    read -p "Email: " EMAIL

    # Login (will prompt for password)
    echo ""
    echo "Logging in..."
    bw login "$EMAIL"
fi

# Unlock and get session token
echo ""
echo "🔓 Unlocking vault..."
export BW_SESSION=$(bw unlock --raw)

if [ -z "$BW_SESSION" ]; then
    echo "❌ Failed to unlock vault"
    exit 1
fi

echo "✅ Vault unlocked"

# Get all items
echo ""
echo "📥 Fetching vault items..."
ITEMS=$(bw list items --session "$BW_SESSION")
ITEM_COUNT=$(echo "$ITEMS" | jq 'length')
echo "📦 Retrieved $ITEM_COUNT vault items"

# Find items with HTTP URIs
echo ""
echo "🔍 Searching for HTTP URIs..."

HTTP_ITEMS=$(echo "$ITEMS" | jq '[.[] | select(.type == 1 and .login.uris != null) | select(.login.uris | any(.uri | startswith("http://")))]')
HTTP_COUNT=$(echo "$HTTP_ITEMS" | jq 'length')

if [ "$HTTP_COUNT" -eq 0 ]; then
    echo ""
    echo "✅ No HTTP URIs found. All URIs are already secure!"
    bw lock
    exit 0
fi

echo "Found $HTTP_COUNT items with HTTP URIs:"
echo "======================================"

# Display items with HTTP URIs
echo "$HTTP_ITEMS" | jq -r '.[] | "
\(.name)
  ID: \(.id)
  URIs: \(.login.uris | map(select(.uri | startswith("http://"))) | map("  🔓 " + .uri) | join("\n"))"'

echo ""
echo "======================================"
echo "📊 Summary: $HTTP_COUNT items with HTTP URIs found"

# Check for dry-run mode
if [ "$1" = "--dry-run" ]; then
    echo ""
    echo "🔍 DRY RUN MODE - No changes will be made"
    echo ""
    echo "To update these items, run this script without --dry-run flag"
    bw lock
    exit 0
fi

# Ask for confirmation
echo ""
read -p "❓ Proceed with updating these items? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ] && [ "$CONFIRM" != "y" ]; then
    echo "❌ Update cancelled."
    bw lock
    exit 0
fi

# Update items
echo ""
echo "🔄 Updating vault items..."

SUCCESS_COUNT=0
FAIL_COUNT=0

for i in $(seq 0 $(($HTTP_COUNT - 1))); do
    ITEM=$(echo "$HTTP_ITEMS" | jq -r ".[$i]")
    ITEM_ID=$(echo "$ITEM" | jq -r '.id')
    ITEM_NAME=$(echo "$ITEM" | jq -r '.name')

    # Update HTTP to HTTPS in URIs
    UPDATED_ITEM=$(echo "$ITEM" | jq '
        .login.uris |= map(
            if .uri | startswith("http://") then
                .uri |= sub("^http://"; "https://")
            else
                .
            end
        )
    ')

    # Encode the updated item
    ENCODED_ITEM=$(echo "$UPDATED_ITEM" | jq -c '.')

    # Update the item
    if echo "$ENCODED_ITEM" | bw encode | bw edit item "$ITEM_ID" --session "$BW_SESSION" > /dev/null 2>&1; then
        echo "✅ Updated: $ITEM_NAME"
        ((SUCCESS_COUNT++))
    else
        echo "❌ Failed: $ITEM_NAME"
        ((FAIL_COUNT++))
    fi
done

# Sync vault
if [ $SUCCESS_COUNT -gt 0 ]; then
    echo ""
    echo "🔄 Syncing vault..."
    bw sync --session "$BW_SESSION"
    echo "✅ Vault synced"
fi

# Final summary
echo ""
echo "======================================"
echo "📊 Update Summary:"
echo "   ✅ Successfully updated: $SUCCESS_COUNT"
echo "   ❌ Failed: $FAIL_COUNT"
echo "   📈 Total processed: $HTTP_COUNT"
echo "======================================"

if [ $SUCCESS_COUNT -gt 0 ]; then
    echo ""
    echo "✨ Your vault URIs have been secured!"
fi

# Lock vault
bw lock

echo ""
echo "🔒 Vault locked"
