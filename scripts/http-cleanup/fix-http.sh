#!/bin/bash

# --- Configuration ---
# Set the desired domain list (optional, can be empty)
# Use this if you want to limit the fix to a specific list of domains (e.g., only "adobe.com")
# DOMAIN_FILTER_LIST=("adobe.com" "alltrails.com" "att.com")
DOMAIN_FILTER_LIST=()

# Vaultwarden credentials
export BW_PASSWORD='dysyN4NxYHMWaMs'
VAULTWARDEN_URL="https://vaultwarden-railway-production.up.railway.app"
CLIENT_ID="REDACTED_BW_CLIENT_ID"
CLIENT_SECRET="REDACTED_BW_CLIENT_SECRET"
# ---------------------

echo "🔐 Bulk HTTP to HTTPS Conversion"
echo "================================="
echo ""

# Configure and login
bw config server "$VAULTWARDEN_URL" 2>/dev/null || true
export BW_CLIENTID="$CLIENT_ID"
export BW_CLIENTSECRET="$CLIENT_SECRET"
bw login --apikey 2>/dev/null || echo "Already logged in"

# Unlock vault and get session
echo "🔓 Unlocking vault..."
export BW_SESSION=$(bw unlock --passwordenv BW_PASSWORD --raw)

if [ -z "$BW_SESSION" ]; then
    echo "❌ Failed to unlock vault"
    exit 1
fi

echo "✅ Vault unlocked"
echo ""
echo "📥 Fetching all vault items..."

# 1. Get ALL items from the vault with http:// URIs
ITEM_DATA=$(bw list items --session "$BW_SESSION" | jq -c '
    .[] | select(.login and .login.uris != null) |
    select(.login.uris | any(.uri | startswith("http://"))) |
    {
        id: .id,
        name: .name,
        uris: .login.uris
    }'
)

# Count total items to process
TOTAL_ITEMS=$(echo "$ITEM_DATA" | wc -l)

if [ "$TOTAL_ITEMS" -eq 0 ]; then
    echo "✅ No items found with http:// URIs"
    bw lock
    exit 0
fi

echo "Found $TOTAL_ITEMS items with http:// URIs"
echo ""
echo "🔄 Starting conversion..."
echo ""

# Initialize a counter
UPDATED_COUNT=0
FAILED_COUNT=0

# 2. Process each item
while IFS= read -r item_json; do
    if [ -z "$item_json" ]; then
        continue
    fi

    ID=$(echo "$item_json" | jq -r '.id')
    NAME=$(echo "$item_json" | jq -r '.name')
    URIS=$(echo "$item_json" | jq -c '.uris')

    # jq expression to replace http:// with https://
    UPDATED_URIS=$(echo "$URIS" | jq '
        map(
            if .uri | startswith("http://") then
                (.uri |= sub("^http://"; "https://"))
            else
                .
            end
        )
    ')

    # Check if any URI was actually modified
    if [ "$URIS" != "$UPDATED_URIS" ]; then
        # Get the full item, replace URIs, and update
        FULL_ITEM=$(bw get item "$ID" --session "$BW_SESSION")

        if [ $? -eq 0 ]; then
            # Update the URIs in the full item
            UPDATED_ITEM=$(echo "$FULL_ITEM" | jq --argjson new_uris "$UPDATED_URIS" '.login.uris = $new_uris')

            # Save to temp file and update
            echo "$UPDATED_ITEM" > /tmp/bw_update_$$.json

            if bw edit item "$ID" /tmp/bw_update_$$.json --session "$BW_SESSION" > /dev/null 2>&1; then
                echo "✅ $NAME"
                UPDATED_COUNT=$((UPDATED_COUNT + 1))
            else
                echo "❌ $NAME (update failed)"
                FAILED_COUNT=$((FAILED_COUNT + 1))
            fi

            # Clean up temp file
            rm -f /tmp/bw_update_$$.json

            # Optional: Wait briefly to avoid hitting rate limits
            sleep 0.1
        else
            echo "❌ $NAME (fetch failed)"
            FAILED_COUNT=$((FAILED_COUNT + 1))
        fi
    fi

done <<< "$ITEM_DATA"

# Sync vault
echo ""
echo "🔄 Syncing vault..."
bw sync --session "$BW_SESSION" > /dev/null 2>&1

# Lock vault
bw lock

echo ""
echo "======================================"
echo "✅ Batch conversion complete!"
echo "======================================"
echo "   Successfully updated: $UPDATED_COUNT"
echo "   Failed: $FAILED_COUNT"
echo "   Total processed: $TOTAL_ITEMS"
echo "======================================"
echo ""
echo "🔒 Vault locked"
