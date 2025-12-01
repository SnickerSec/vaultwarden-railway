#!/bin/bash
# Working HTTP to HTTPS fix script

export BW_PASSWORD='dysyN4NxYHMWaMs'

echo "🔐 HTTP to HTTPS Conversion"
echo "==========================="
echo ""

# Get session
echo "🔓 Unlocking vault..."
BW_SESSION=$(bw unlock --passwordenv BW_PASSWORD --raw)

echo "✅ Vault unlocked (session: ${BW_SESSION:0:10}...)"
echo ""

# Get all HTTP items
echo "📥 Fetching HTTP items..."
HTTP_ITEMS=$(bw list items --session "$BW_SESSION" | jq -c '.[] | select(.type == 1) | select(.login.uris != null) | select(.login.uris | any(.uri | startswith("http://")))')

TOTAL=$(echo "$HTTP_ITEMS" | wc -l)
echo "Found $TOTAL items with HTTP URIs"
echo ""

if [ "$TOTAL" -eq 0 ]; then
    echo "✅ No items to update!"
    bw lock
    exit 0
fi

echo "🔄 Updating items..."
echo ""

SUCCESS=0
FAILED=0

while IFS= read -r item; do
    if [ -z "$item" ]; then
        continue
    fi

    ID=$(echo "$item" | jq -r '.id')
    NAME=$(echo "$item" | jq -r '.name')

    # Get full item
    FULL=$(bw get item "$ID" --session "$BW_SESSION" 2>/dev/null)

    if [ -z "$FULL" ]; then
        echo "❌ $NAME (fetch failed)"
        FAILED=$((FAILED + 1))
        continue
    fi

    # Update URIs
    UPDATED=$(echo "$FULL" | jq '.login.uris |= map(if .uri | startswith("http://") then (.uri |= sub("^http://"; "https://")) else . end)')

    # Save and update
    echo "$UPDATED" > /tmp/bw_item_$ID.json

    if echo "$UPDATED" | bw encode | bw edit item "$ID" --session "$BW_SESSION" > /dev/null 2>&1; then
        echo "✅ $NAME"
        SUCCESS=$((SUCCESS + 1))
    else
        echo "❌ $NAME (update failed)"
        FAILED=$((FAILED + 1))
    fi

    rm -f /tmp/bw_item_$ID.json
    sleep 0.1

done <<< "$HTTP_ITEMS"

echo ""
echo "🔄 Syncing..."
bw sync --session "$BW_SESSION" > /dev/null 2>&1

echo ""
echo "======================================"
echo "✅ Complete!"
echo "   Successful: $SUCCESS"
echo "   Failed: $FAILED"
echo "   Total: $TOTAL"
echo "======================================"

bw lock
echo "🔒 Vault locked"
